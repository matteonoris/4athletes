import { createClient } from '@supabase/supabase-js';

// Custom authentication: a server-created 256-bit ticket, bound to one queued
// request, expires in five minutes and is consumed atomically by the claim RPC.
// No user ID from the caller is ever trusted. Platform JWT verification must be
// disabled because the Cron worker uses this single-use capability instead.
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response(null, { status: 405 });
  if ((Number(req.headers.get('content-length')) || 0) > 2048) {
    return new Response(null, { status: 413 });
  }
  // Content-Length is optional/untrusted. Also cap streamed request bodies.
  const reader = req.body?.getReader();
  if (!reader) return new Response(null, { status: 400 });
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > 2048) {
      await reader.cancel();
      return new Response(null, { status: 413 });
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let input: { job?: string; ticket?: string };
  try { input = JSON.parse(new TextDecoder().decode(bytes)); } catch {
    return new Response(null, { status: 400 });
  }
  if (!input || typeof input.job !== 'string' ||
      !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(input.job) || typeof input.ticket !== 'string' ||
      !/^[a-f0-9]{64}$/.test(input.ticket)) {
    return new Response(null, { status: 401 });
  }
  const admin = createClient(Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: claim, error: claimError } = await admin.rpc(
    'claim_account_deletion', { job: input.job, ticket: input.ticket });
  if (claimError) return new Response(null, { status: 503 });
  if (!claim) return new Response(null, { status: 401 });
  let stage = 'auth';
  try {
    // Block new sign-ins during retries. An absent user is an idempotent retry
    // after Auth deletion succeeded but recording completion failed.
    const { data: existing, error: lookupError } =
      await admin.auth.admin.getUserById(claim.user_id);
    if (lookupError && lookupError.status !== 404) throw lookupError;
    if (existing.user) {
      const { error } = await admin.auth.admin.updateUserById(claim.user_id,
        { ban_duration: '876000h' });
      if (error) throw error;
    }
    stage = 'storage';
    const groups = new Map<string, string[]>();
    for (const object of claim.objects) {
      const paths = groups.get(object.bucket) ?? [];
      paths.push(object.name);
      groups.set(object.bucket, paths);
    }
    for (const [bucket, paths] of groups) {
      for (let offset = 0; offset < paths.length; offset += 100) {
        const { error } = await admin.storage.from(bucket)
          .remove(paths.slice(offset, offset + 100));
        if (error) throw error;
      }
    }
    stage = 'auth';
    if (existing.user) {
      const { error } = await admin.auth.admin.deleteUser(claim.user_id, false);
      if (error) throw error;
    }
    const { error } = await admin.rpc('finish_account_deletion', {
      job: input.job, worker_lease: claim.lease });
    if (error) throw error;
    return Response.json({ status: 'completed' });
  } catch {
    // Never log tokens, emails, object paths or raw provider errors.
    await admin.rpc('finish_account_deletion', {
      job: input.job, worker_lease: claim.lease, error_code: stage });
    return Response.json({ status: 'retrying' }, { status: 503 });
  }
});
