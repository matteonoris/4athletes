-- User initiated hard deletion. No existing account is removed by this migration.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create table private.account_deletions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique, -- cleared after successful Auth/Storage deletion
 receipt_hash bytea not null unique,
 status text not null default 'pending' check (status in ('pending','processing','completed')),
 requested_at timestamptz not null default now(),
 completed_at timestamptz,
 next_attempt_at timestamptz not null default now(),
 attempts integer not null default 0,
 ticket_hash bytea,
 ticket_expires_at timestamptz,
 lease uuid,
 lease_expires_at timestamptz,
 last_error text -- fixed operational code, never raw error/email/token
);
alter table private.account_deletions enable row level security;
revoke all on private.account_deletions from public, anon, authenticated;
create index account_deletions_retry on private.account_deletions(next_attempt_at) where status <> 'completed';

-- Reject a deleted/pending identity even while its old signed JWT is unexpired.
create function private.account_is_active() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null
 and exists(select 1 from auth.users where id=auth.uid())
 and not exists(select 1 from private.account_deletions where user_id=auth.uid());
$$;
revoke all on function private.account_is_active() from public, anon;
grant execute on function private.account_is_active() to authenticated;
do $$declare t text;begin
 foreach t in array array['profiles','teams','team_memberships','training_sessions','body_metric_logs','pr_logs','jump_logs','hrv_baselines','calendar_events','notifications','health_consent_events'] loop
  execute format('create policy account_must_be_active on public.%I as restrictive for all to authenticated using ((select private.account_is_active())) with check ((select private.account_is_active()))',t);
 end loop;
end $$;
create policy account_must_be_active on storage.objects as restrictive for all to authenticated
 using ((select private.account_is_active())) with check ((select private.account_is_active()));

-- Remove identified participants (including names/health answers) from nested
-- copies of planned workouts; remove author identifiers without deleting peers.
create function private.scrub_deleted_identity(value jsonb, u uuid) returns jsonb
language plpgsql immutable set search_path='' as $$
declare result jsonb; k text; v jsonb; cleaned jsonb;
begin
 if value is null then return null; end if;
 if jsonb_typeof(value)='object' then
  if value->>'id'=u::text or value->>'athleteId'=u::text or value->>'athlete_id'=u::text or value->>'user_id'=u::text then return null; end if;
  result:='{}';
  for k,v in select * from jsonb_each(value) loop
   if k=u::text then continue; end if;
   cleaned:=private.scrub_deleted_identity(v,u);
   if cleaned is not null then result:=result||jsonb_build_object(k,cleaned); end if;
  end loop;
 elsif jsonb_typeof(value)='array' then
  result:='[]';
  for v in select * from jsonb_array_elements(value) loop
   cleaned:=private.scrub_deleted_identity(v,u);
   if cleaned is not null then result:=result||jsonb_build_array(cleaned); end if;
  end loop;
 elsif value=to_jsonb(u::text) then return null;
 else return value;
 end if;
 return result;
end $$;
revoke all on function private.scrub_deleted_identity(jsonb,uuid) from public,anon,authenticated;

create function private.purge_account_records(u uuid) returns void
language plpgsql security definer set search_path='' as $$
declare affected_teams uuid[];
begin
 -- Serialize with manager operations; do not promote anyone automatically.
 perform 1 from public.teams where id in(select team_id from public.team_memberships where user_id=u) order by id for update;
 select coalesce(array_agg(team_id),'{}') into affected_teams from public.team_memberships where user_id=u;
 delete from public.training_sessions where user_id=u;
 delete from public.body_metric_logs where user_id=u;
 delete from public.pr_logs where user_id=u;
 delete from public.jump_logs where user_id=u;
 delete from public.hrv_baselines where user_id=u;
 delete from public.notifications where user_id=u;
 delete from public.health_consent_events where user_id=u;
 -- Personal calendar entries have no other team's interest to preserve.
 delete from public.calendar_events where created_by=u and team_id is null
  and not exists(select 1 from private.event_teams(team_id,technical_details) t(id) where t.id is not null);
 update public.calendar_events set
  created_by=case when created_by=u then null else created_by end,
  attendees=coalesce(private.scrub_deleted_identity(attendees,u),'[]'),
  technical_details=private.scrub_deleted_identity(technical_details,u)
 where created_by=u or attendees::text like '%'||u::text||'%' or technical_details::text like '%'||u::text||'%';
 update public.training_sessions set details=private.scrub_deleted_identity(details,u)
 where details::text like '%'||u::text||'%';
 -- Other members' records remain; removing the only manager leaves a team to
 -- be reassigned by the operator, rather than denying the deletion request.
 delete from public.team_memberships where user_id=u;
 update public.team_memberships set approved_by=null where approved_by=u;
 update public.teams set members=(select count(*) from public.team_memberships m where m.team_id=public.teams.id and m.status='active') where id=any(affected_teams);
 delete from private.team_audit where actor_id=u or subject_id=u
  or previous_state::text like '%'||u::text||'%' or next_state::text like '%'||u::text||'%';
 delete from private.invite_attempts where user_id=u;
 delete from public.profiles where id=u;
 delete from auth.sessions where user_id=u;
end $$;
revoke all on function private.purge_account_records(uuid) from public,anon,authenticated;

-- Operator-only entry point for externally received, already verified requests.
-- Never expose this as an anonymous/user-callable RPC.
create function private.enqueue_verified_account_deletion(u uuid,receipt text) returns uuid
language plpgsql security definer set search_path='' as $$
declare j uuid;
begin
 if u is null or receipt is null or receipt !~ '^[a-f0-9]{64}$' then raise exception 'Richiesta non valida'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into j from private.account_deletions where user_id=u;
 if j is not null then return j; end if;
 if not exists(select 1 from auth.users where id=u) then raise exception 'Account non trovato'; end if;
 insert into private.account_deletions(user_id,receipt_hash) values(u,extensions.digest(receipt,'sha256')) returning id into j;
 perform private.purge_account_records(u);
 return j;
end $$;
revoke all on function private.enqueue_verified_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function private.enqueue_verified_account_deletion(uuid,text) to service_role;

create function private.request_account_deletion(confirmation text, receipt text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); j private.account_deletions; sid uuid;
begin
 if u is null or confirmation is distinct from 'ELIMINA' or receipt !~ '^[a-f0-9]{64}$' or receipt is null then
  raise exception 'Conferma non valida' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select * into j from private.account_deletions where user_id=u;
 if j.id is not null then
  if j.receipt_hash<>extensions.digest(receipt,'sha256') then raise exception 'Richiesta già presente' using errcode='42501'; end if;
  return jsonb_build_object('status',j.status);
 end if;
 sid:=nullif(auth.jwt()->>'session_id','')::uuid;
 if not exists(select 1 from auth.sessions s join auth.users a on a.id=s.user_id
  where s.id=sid and s.user_id=u and s.created_at>now()-interval '10 minutes'
  and a.deleted_at is null and (a.banned_until is null or a.banned_until<now())) then
  raise exception 'Accedi di nuovo prima di eliminare l''account' using errcode='42501',hint='recent_login_required';
 end if;
 insert into private.account_deletions(user_id,receipt_hash) values(u,extensions.digest(receipt,'sha256')) returning * into j;
 perform private.purge_account_records(u);
 return jsonb_build_object('status',j.status);
end $$;
create function public.request_account_deletion(confirmation text,receipt text) returns jsonb
language sql security invoker set search_path='' as $$select private.request_account_deletion(confirmation,receipt);$$;
revoke all on function private.request_account_deletion(text,text),public.request_account_deletion(text,text) from public,anon;
grant execute on function private.request_account_deletion(text,text),public.request_account_deletion(text,text) to authenticated;

-- Possession of the random 256-bit receipt permits status-only access after
-- logout. It never permits deleting an account or discovering an email/user ID.
create function private.account_deletion_status(receipt text) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('status',status,'requested_at',requested_at,'completed_at',completed_at)
 from private.account_deletions where receipt ~ '^[a-f0-9]{64}$'
 and receipt_hash=extensions.digest(receipt,'sha256')
 and (completed_at is null or completed_at>now()-interval '30 days');
$$;
create function public.account_deletion_status(receipt text) returns jsonb
language sql security invoker set search_path='' as $$select private.account_deletion_status(receipt);$$;
revoke all on function private.account_deletion_status(text),public.account_deletion_status(text) from public;
grant execute on function private.account_deletion_status(text),public.account_deletion_status(text) to anon,authenticated;
grant usage on schema private to anon;
alter default privileges in schema private revoke execute on functions from public;

-- The cron dispatcher creates short lived, single-use worker tickets. No
-- service key is stored in SQL, client code, or the request body.
create function private.dispatch_account_deletions() returns void
language plpgsql security definer set search_path='' as $$
declare j private.account_deletions; ticket text;
begin
 for j in select * from private.account_deletions where status<>'completed'
  and next_attempt_at<=now() and (lease_expires_at is null or lease_expires_at<now())
  and (ticket_expires_at is null or ticket_expires_at<now())
  order by requested_at limit 5 for update skip locked loop
  ticket:=encode(extensions.gen_random_bytes(32),'hex');
  update private.account_deletions set ticket_hash=extensions.digest(ticket,'sha256'),ticket_expires_at=now()+interval '5 minutes' where id=j.id;
  perform net.http_post(
   url:='https://hqzushizdfxrnktoqbtr.supabase.co/functions/v1/delete-account-worker',
   headers:=jsonb_build_object('Content-Type','application/json'),
   body:=jsonb_build_object('job',j.id,'ticket',ticket),timeout_milliseconds:=10000);
 end loop;
 delete from private.account_deletions where status='completed' and completed_at<now()-interval '30 days';
end $$;
revoke all on function private.dispatch_account_deletions() from public,anon,authenticated;

create function private.claim_account_deletion(job uuid,ticket text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.account_deletions; objects jsonb; l uuid:=gen_random_uuid();
begin
 select * into j from private.account_deletions where id=job for update;
 if j.id is null or j.status='completed' or ticket is null or ticket !~ '^[a-f0-9]{64}$'
  or j.ticket_hash is null or j.ticket_hash<>extensions.digest(ticket,'sha256')
  or j.ticket_expires_at<=now() or (j.lease_expires_at is not null and j.lease_expires_at>now()) then return null; end if;
 select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket_id,'name',name)),'[]') into objects
 from storage.objects where owner=j.user_id or owner_id=j.user_id::text
  or (bucket_id='avatars' and name like j.user_id::text||'/%');
 update private.account_deletions set status='processing',ticket_hash=null,ticket_expires_at=null,
  lease=l,lease_expires_at=now()+interval '5 minutes',attempts=attempts+1 where id=j.id;
 return jsonb_build_object('user_id',j.user_id,'lease',l,'objects',objects);
end $$;
create function public.claim_account_deletion(job uuid,ticket text) returns jsonb
language sql security invoker set search_path='' as $$select private.claim_account_deletion(job,ticket);$$;
revoke all on function private.claim_account_deletion(uuid,text),public.claim_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function private.claim_account_deletion(uuid,text),public.claim_account_deletion(uuid,text) to service_role;

create function private.finish_account_deletion(job uuid,worker_lease uuid,error_code text default null) returns void
language plpgsql security definer set search_path='' as $$
declare j private.account_deletions;
begin
 select * into j from private.account_deletions where id=job for update;
 if j.id is null or j.status<>'processing' or j.lease is distinct from worker_lease then raise exception 'Worker non autorizzato' using errcode='42501'; end if;
 if error_code is null then
  if exists(select 1 from auth.users where id=j.user_id) or exists(select 1 from storage.objects where owner=j.user_id or owner_id=j.user_id::text or (bucket_id='avatars' and name like j.user_id::text||'/%')) then
   raise exception 'Cancellazione incompleta'; end if;
  update private.account_deletions set user_id=null,status='completed',completed_at=now(),lease=null,lease_expires_at=null,last_error=null where id=j.id;
 else
  update private.account_deletions set status='pending',lease=null,lease_expires_at=null,
   next_attempt_at=now()+make_interval(mins=>least(60,greatest(1,attempts*2))),
   last_error=case when error_code in ('storage','auth','unexpected') then error_code else 'unexpected' end where id=j.id;
 end if;
end $$;
create function public.finish_account_deletion(job uuid,worker_lease uuid,error_code text default null) returns void
language sql security invoker set search_path='' as $$select private.finish_account_deletion(job,worker_lease,error_code);$$;
revoke all on function private.finish_account_deletion(uuid,uuid,text),public.finish_account_deletion(uuid,uuid,text) from public,anon,authenticated;
grant execute on function private.finish_account_deletion(uuid,uuid,text),public.finish_account_deletion(uuid,uuid,text) to service_role;

select cron.schedule('4athletes-account-deletion','* * * * *','select private.dispatch_account_deletions()');
