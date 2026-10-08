// Run only for an explicitly created synthetic identity, never a real user.
// API tokens stay in this process; the status-only receipt is saved temporarily.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
const uid = process.argv[2];
if (!/^[a-f0-9-]{36}$/.test(uid ?? '')) throw Error('Synthetic UUID required');
const env = Object.fromEntries(fs.readFileSync('flutter_mobile/.env', 'utf8')
  .split(/\r?\n/).filter(line => /^(SUPABASE_URL|SUPABASE_ANON_KEY)=/.test(line))
  .map(line => { const index = line.indexOf('='); return [line.slice(0, index),
    line.slice(index + 1).trim().replace(/^['"]|['"]$/g, '')]; }));
const base = env.SUPABASE_URL;
const receiptFile = path.join(os.tmpdir(), `4athletes-deletion-test-${uid}.json`);
async function api(route, body, token, method = 'POST', contentType = 'application/json') {
  const response = await fetch(`${base}${route}`, { method,
    headers: { apikey: env.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${token ?? env.SUPABASE_ANON_KEY}`,
      'Content-Type': contentType },
    body: method === 'GET' ? undefined :
      contentType === 'application/json' ? JSON.stringify(body) : body });
  const text = await response.text();
  let result; try { result = JSON.parse(text); } catch { result = null; }
  return { status: response.status, result };
}
function check(value, label) { if (!value) throw Error(`Failed: ${label}`); }
if (process.argv[3] !== 'status') {
  const login = await api('/auth/v1/token?grant_type=password', {
    email: `delete-test-${uid}@example.invalid`, password: `Deletion-test!${uid}` });
  check(login.status === 200 && login.result?.user?.id === uid, 'synthetic login');
  const token = login.result.access_token;
  const refreshToken = login.result.refresh_token;
  const receipt = crypto.randomBytes(32).toString('hex');
  const photo = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jM1kAAAAASUVORK5CYII=', 'base64');
  const upload = await api(`/storage/v1/object/avatars/${uid}/synthetic-${crypto.randomUUID()}.png`, photo,
    token, 'POST', 'image/png');
  check(upload.status === 200, 'real Storage upload');
  const wrong = await api('/rest/v1/rpc/request_account_deletion', {
    confirmation: 'NO', receipt }, token);
  check(wrong.status === 400, 'confirmation rejected');
  const outsider = await api('/functions/v1/delete-account-worker', {
    job: crypto.randomUUID(), ticket: crypto.randomBytes(32).toString('hex') });
  check(outsider.status === 401, 'worker capability required');
  fs.writeFileSync(receiptFile, JSON.stringify({ receipt }), { mode: 0o600 });
  const request = await api('/rest/v1/rpc/request_account_deletion', {
    confirmation: 'ELIMINA', receipt }, token);
  check(request.status === 200 && request.result?.status === 'pending', 'deletion accepted');
  const staleRead = await api(`/rest/v1/profiles?id=eq.${uid}&select=id`, null, token, 'GET');
  check(staleRead.status === 200 && staleRead.result.length === 0, 'old JWT cannot read profile');
  const staleWrite = await api('/rest/v1/profiles', {
    id: uid, role: 'athlete', birth_date: '2000-01-01' }, token);
  check(staleWrite.status === 401 || staleWrite.status === 403, 'old JWT cannot recreate profile');
  const staleUpload = await api(`/storage/v1/object/avatars/${uid}/recreated.png`, photo,
    token, 'POST', 'image/png');
  check(staleUpload.status >= 400, 'old JWT cannot recreate photo');
  const refresh = await api('/auth/v1/token?grant_type=refresh_token', {
    refresh_token: refreshToken });
  check(refresh.status >= 400, 'revoked session cannot refresh');
  console.log('PASS: login, real photo upload, confirmation, queue, stale JWT and refresh rejection');
}
const { receipt } = JSON.parse(fs.readFileSync(receiptFile, 'utf8'));
const status = await api('/rest/v1/rpc/account_deletion_status', { receipt });
check(status.status === 200 && status.result?.status, 'anonymous receipt status');
check(!('user_id' in status.result) && !('email' in status.result), 'status contains no identity');
console.log(`Deletion status: ${status.result.status}`);
if (status.result.status === 'completed') {
  const login = await api('/auth/v1/token?grant_type=password', {
    email: `delete-test-${uid}@example.invalid`, password: `Deletion-test!${uid}` });
  check(login.status >= 400, 'deleted account cannot sign in');
  fs.unlinkSync(receiptFile);
  console.log('PASS: automatic worker completed and removed Auth identity');
}
