create or replace function private.purge_account_records(u uuid) returns void
language plpgsql security definer set search_path='' as $$
declare affected_teams uuid[]; previous_suppression text:=current_setting('4athletes.account_deletion',true);
begin
 perform set_config('4athletes.account_deletion','on',true);
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
 perform set_config('4athletes.account_deletion',coalesce(previous_suppression,''),true);
end $$;

-- Deleting an author must not send spurious workout-update notifications to
-- real peers. The flag is private, transaction-scoped and restored by the purge.
create or replace function private.notify_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare a jsonb;
begin
 if current_setting('4athletes.account_deletion',true)='on' then return null; end if;
 if not private.can_manage_event(new.team_id,new.technical_details,new.created_by) and auth.uid() is not null then return null; end if;
 if new.date<current_date and new.status<>'cancelled' then return null; end if;
 for a in select value from jsonb_array_elements(coalesce(new.attendees,'[]')) loop
  if tg_op='UPDATE' and (to_jsonb(new)-'attendees')=(to_jsonb(old)-'attendees') and exists(select 1 from jsonb_array_elements(coalesce(old.attendees,'[]')) prior where prior->>'id'=a->>'id') then continue; end if;
  insert into public.notifications(user_id,title,message,timestamp,type,is_read,event_id)
  values((a->>'id')::uuid,case when new.status='cancelled' then 'Allenamento annullato' else 'Allenamento aggiornato' end,
   new.title||' — '||new.date::text||' alle '||new.start_time::text,now(),'training',false,new.id);
 end loop;
 return null;
end $$;
