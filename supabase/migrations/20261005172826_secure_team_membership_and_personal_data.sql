-- Reviewed upgrade for the verified production schema (2026-10-05).
-- Applied with MCP; copied to migrations using the server-assigned version.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Delete only the explicitly approved empty test teams. Abort on new links.
do $$
begin
  if exists(select 1 from public.teams t where t.name in ('Goggi Senior','Boogie','Sci club Zanetti Goggi') and
    (exists(select 1 from public.profiles p where p.team_id=t.id) or
     exists(select 1 from public.calendar_events e where e.team_id=t.id or e.technical_details->'teamIds' ? t.id::text))) then
    raise exception 'Le squadre di prova hanno nuovi collegamenti: cancellazione interrotta';
  end if;
  delete from public.teams where name in ('Goggi Senior','Boogie','Sci club Zanetti Goggi');
end $$;

create table public.team_memberships (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check(role in ('athlete','coach')),
  status text not null default 'pending' check(status in ('active','pending')),
  is_manager boolean not null default false,
  joined_at timestamptz not null default now(),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  primary key(team_id,user_id),
  check(not is_manager or (role='coach' and status='active'))
);
create index team_memberships_user_idx on public.team_memberships(user_id,status,team_id);
create unique index athlete_one_active_team on public.team_memberships(user_id) where role='athlete' and status='active';
create table private.team_audit (
  id bigint generated always as identity primary key,
  team_id uuid, actor_id uuid, subject_id uuid, action text not null,
  previous_state jsonb, next_state jsonb, occurred_at timestamptz not null default now()
);
create table private.invite_attempts (user_id uuid primary key references auth.users(id) on delete cascade, window_start timestamptz not null, attempts integer not null);
alter table private.team_audit enable row level security;
alter table private.invite_attempts enable row level security;
alter table public.team_memberships enable row level security;
revoke all on public.team_memberships from public,anon,authenticated;
revoke all on private.team_audit,private.invite_attempts from public,anon,authenticated;

insert into public.team_memberships(team_id,user_id,role,status,is_manager,approved_at)
select p.team_id,p.id,p.role,'active',p.role='coach',now()
from public.profiles p join public.teams t on t.id=p.team_id
where t.name in ('Zanetti Goggi Giovani Senior','Team Batti') and p.role in ('athlete','coach');
do $$
begin
  if (select count(*) from public.team_memberships m join public.teams t on t.id=m.team_id where t.name='Zanetti Goggi Giovani Senior' and m.is_manager)<>5
     or (select count(*) from public.team_memberships m join public.teams t on t.id=m.team_id where t.name='Team Batti' and m.is_manager)<>1
     or exists(select 1 from public.profiles p where p.team_id is not null and not exists(select 1 from public.team_memberships m where m.user_id=p.id and m.team_id=p.team_id)) then
    raise exception 'La composizione delle squadre è cambiata: verificare i responsabili';
  end if;
end $$;
insert into private.team_audit(team_id,subject_id,action,next_state)
select team_id,user_id,'owner_confirmed_bootstrap',to_jsonb(m) from public.team_memberships m;
update public.teams t set members=(select count(*) from public.team_memberships m where m.team_id=t.id and m.status='active'), invite_code=upper(replace(gen_random_uuid()::text,'-',''));
alter table public.teams add constraint teams_invite_code_unique unique(invite_code);
alter table public.profiles add constraint profiles_auth_identity foreign key(id) references auth.users(id);

create function private.is_member(t uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.team_memberships m where m.team_id=t and m.user_id=(select auth.uid()) and m.status='active');
$$;
create function private.is_coach(t uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.team_memberships m where m.team_id=t and m.user_id=(select auth.uid()) and m.status='active' and m.role='coach');
$$;
create function private.is_manager(t uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.team_memberships m where m.team_id=t and m.user_id=(select auth.uid()) and m.status='active' and m.is_manager);
$$;
create function private.can_coach(u uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.team_memberships a join public.team_memberships c on c.team_id=a.team_id
    where a.user_id=u and a.role='athlete' and a.status='active' and c.user_id=(select auth.uid()) and c.role='coach' and c.status='active');
$$;
create function private.event_teams(t uuid,d jsonb) returns setof uuid language sql immutable set search_path='' as $$
  select t where t is not null union
  select v::uuid from jsonb_array_elements_text(case when jsonb_typeof(d->'teamIds')='array' then d->'teamIds' else '[]'::jsonb end) v;
$$;
create function private.can_manage_event(t uuid,d jsonb,creator uuid) returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and
    case when exists(select 1 from private.event_teams(t,d)) then
      not exists(select 1 from private.event_teams(t,d) x where not private.is_coach(x))
    else creator=auth.uid() and exists(select 1 from public.profiles where id=auth.uid() and role='coach') end;
$$;
create function private.can_attend_event(e public.calendar_events) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.event_teams(e.team_id,e.technical_details) t join public.team_memberships m on m.team_id=t
    where m.user_id=auth.uid() and m.role='athlete' and m.status='active')
    and (jsonb_array_length(coalesce(e.attendees,'[]'::jsonb))=0 or exists(select 1 from jsonb_array_elements(e.attendees) a where a->>'id'=auth.uid()::text));
$$;

-- Client profile upserts may echo protected fields, but cannot change them.
create function private.guard_profile() returns trigger language plpgsql set search_path='' as $$
declare previous public.profiles;
begin
  if current_user in ('postgres','service_role','supabase_admin') then return new; end if;
  if new.id is distinct from auth.uid() then raise exception 'Profilo non autorizzato' using errcode='42501'; end if;
  if tg_op='UPDATE' then previous:=old; else select * into previous from public.profiles where id=new.id; end if;
  if previous.id is not null then
    if new.role is distinct from previous.role or new.team_id is distinct from previous.team_id then
      raise exception 'Ruolo e squadra sono gestiti dal server' using errcode='42501';
    end if;
  elsif new.role not in ('athlete','coach') or new.role is null or new.team_id is not null then
    raise exception 'Registrazione non valida' using errcode='42501';
  end if;
  if (previous.id is null or new.birth_date is distinct from previous.birth_date) and
     (new.birth_date is null or new.birth_date > (current_date-interval '14 years')::date or new.birth_date < date '1900-01-01') then
    raise exception 'Registrazione consentita dai 14 anni';
  end if;
  return new;
end $$;
create trigger guard_profile before insert or update on public.profiles for each row execute function private.guard_profile();

create function private.team_operation(operation text,t uuid default null,subject uuid default null,payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); p public.profiles; m public.team_memberships; previous jsonb; result jsonb; created uuid; n integer;
begin
  select * into p from public.profiles where id=actor;
  if actor is null or p.id is null then raise exception 'Accesso richiesto' using errcode='42501'; end if;
  if operation='create' then
    if p.role<>'coach' or length(trim(coalesce(payload->>'name','')))=0 or length(payload->>'name')>100 then raise exception 'Solo un allenatore può creare una squadra'; end if;
    insert into public.teams(name,category,image,invite_code,members,is_private) values(trim(payload->>'name'),coalesce(nullif(trim(payload->>'category'),''),'Skiing'),'',upper(replace(gen_random_uuid()::text,'-','')),1,true) returning id into created;
    insert into public.team_memberships(team_id,user_id,role,status,is_manager,approved_by,approved_at) values(created,actor,'coach','active',true,actor,now());
    update public.profiles set team_id=created where id=actor;
    insert into private.team_audit(team_id,actor_id,subject_id,action) values(created,actor,actor,'create');
    return jsonb_build_object('team_id',created,'status','active');
  elsif operation='join' then
    insert into private.invite_attempts values(actor,now(),1) on conflict(user_id) do update
      set attempts=case when private.invite_attempts.window_start < now()-interval '1 minute' then 1 else private.invite_attempts.attempts+1 end,
          window_start=case when private.invite_attempts.window_start < now()-interval '1 minute' then now() else private.invite_attempts.window_start end returning attempts into n;
    -- Return failures rather than raising, so the attempt counter commits.
    if n>5 then return jsonb_build_object('error','Attendi un minuto prima di riprovare.'); end if;
    select id into t from public.teams where invite_code=upper(trim(payload->>'code'));
    if t is null then return jsonb_build_object('error','Codice non valido.'); end if;
    perform 1 from public.teams where id=t for update;
    select * into m from public.team_memberships where team_id=t and user_id=actor;
    if m.user_id is not null then return jsonb_build_object('team_id',t,'status',m.status); end if;
    if p.role='athlete' and exists(select 1 from public.team_memberships where user_id=actor and status='active') then
      return jsonb_build_object('error','Esci dalla squadra attuale prima di unirti a un’altra.'); end if;
    insert into public.team_memberships(team_id,user_id,role,status,approved_at) values(t,actor,p.role,case when p.role='coach' then 'pending' else 'active' end,case when p.role='athlete' then now() end) returning * into m;
    if m.status='active' then update public.profiles set team_id=t where id=actor; end if;
    insert into private.team_audit(team_id,actor_id,subject_id,action,next_state) values(t,actor,actor,'join',to_jsonb(m));
  else
    perform 1 from public.teams where id=t for update;
    if not found then raise exception 'Squadra non trovata'; end if;
    if operation='leave' then subject:=actor; elsif not private.is_manager(t) then raise exception 'Operazione riservata ai responsabili' using errcode='42501'; end if;
    select * into m from public.team_memberships where team_id=t and user_id=subject;
    if m.user_id is null then raise exception 'Membro non trovato'; end if;
    previous:=to_jsonb(m);
    if operation in ('demote','remove','leave') and m.is_manager and
       (select count(*) from public.team_memberships where team_id=t and is_manager and status='active')<=1 then
      raise exception 'Nomina un altro responsabile prima di rimuovere o lasciare questo ruolo'; end if;
    if operation='approve' and m.role='coach' and m.status='pending' then
      update public.team_memberships set status='active',approved_by=actor,approved_at=now() where team_id=t and user_id=subject;
      update public.profiles set team_id=coalesce(team_id,t) where id=subject;
    elsif operation in ('promote','demote') and m.role='coach' and m.status='active' then
      update public.team_memberships set is_manager=(operation='promote') where team_id=t and user_id=subject;
    elsif operation in ('remove','leave') or (operation='reject' and m.status='pending') then
      delete from public.team_memberships where team_id=t and user_id=subject;
      update public.profiles set team_id=(select team_id from public.team_memberships where user_id=subject and status='active' order by joined_at,team_id limit 1) where id=subject and team_id=t;
    else raise exception 'Operazione non valida'; end if;
    insert into private.team_audit(team_id,actor_id,subject_id,action,previous_state,next_state)
      values(t,actor,subject,operation,previous,(select to_jsonb(x) from public.team_memberships x where team_id=t and user_id=subject));
  end if;
  update public.teams set members=(select count(*) from public.team_memberships where team_id=t and status='active') where id=t;
  return jsonb_build_object('team_id',t,'status',coalesce(m.status,'active'));
end $$;
create function public.team_operation(operation text,t uuid default null,subject uuid default null,payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$select private.team_operation(operation,t,subject,payload);$$;

create function private.get_my_teams() returns setof jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(t)-'invite_code' || jsonb_build_object('invite_code',case when m.is_manager then t.invite_code else '' end,'is_manager',m.is_manager,'membership_status',m.status)
 from public.team_memberships m join public.teams t on t.id=m.team_id where m.user_id=auth.uid() order by t.name;
$$;
create function public.get_my_teams() returns setof jsonb language sql security invoker set search_path='' as $$select private.get_my_teams();$$;
create function private.team_directory(t uuid,include_pending boolean default false) returns setof jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'first_name',p.first_name,'last_name',p.last_name,'avatar_url',p.avatar_url,'ski_club',p.ski_club,'skill_level',p.skill_level,'role',m.role,'is_manager',m.is_manager,'status',m.status)
 from public.team_memberships m join public.profiles p on p.id=m.user_id
 where m.team_id=t and private.is_member(t) and (m.status='active' or (include_pending and private.is_manager(t))) order by p.last_name,p.first_name;
$$;
create function public.team_directory(t uuid,include_pending boolean default false) returns setof jsonb language sql security invoker set search_path='' as $$select private.team_directory(t,include_pending);$$;

create function private.guard_owned_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' and new.user_id is distinct from old.user_id then raise exception 'Proprietario del dato immutabile' using errcode='42501'; end if;
 return new;
end $$;
create trigger guard_body_owner before update on public.body_metric_logs for each row execute function private.guard_owned_log();
create trigger guard_pr_owner before update on public.pr_logs for each row execute function private.guard_owned_log();
create trigger guard_jump_owner before update on public.jump_logs for each row execute function private.guard_owned_log();
create trigger guard_hrv_owner before update on public.hrv_baselines for each row execute function private.guard_owned_log();

create function private.guard_event() returns trigger language plpgsql set search_path='' as $$
declare a jsonb; aid uuid;
begin
 if current_user in ('postgres','service_role','supabase_admin') then return new; end if;
 if tg_op='UPDATE' and new.created_by is distinct from old.created_by then raise exception 'Autore immutabile' using errcode='42501'; end if;
 if tg_op='INSERT' and new.created_by is distinct from auth.uid() then raise exception 'Autore non valido' using errcode='42501'; end if;
 if not private.can_manage_event(new.team_id,new.technical_details,new.created_by) then raise exception 'Squadra non autorizzata' using errcode='42501'; end if;
 if new.attendees is not null and jsonb_typeof(new.attendees)<>'array' then raise exception 'Inviti non validi'; end if;
 for a in select value from jsonb_array_elements(coalesce(new.attendees,'[]')) loop
   aid:=(a->>'id')::uuid;
   if aid is null or not private.valid_event_attendee(aid,new.team_id,new.technical_details) then
     raise exception 'Atleta non autorizzato' using errcode='42501'; end if;
 end loop;
 if (select count(*) from jsonb_array_elements(coalesce(new.attendees,'[]'))) <> (select count(distinct a->>'id') from jsonb_array_elements(coalesce(new.attendees,'[]')) a) then raise exception 'Inviti duplicati'; end if;
 return new;
end $$;
create function private.valid_event_attendee(u uuid,t uuid,d jsonb) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.can_manage_event(t,d,auth.uid()) and exists(select 1 from public.team_memberships m where m.user_id=u and m.role='athlete' and m.status='active' and m.team_id in(select private.event_teams(t,d)));
$$;
create trigger guard_event before insert or update on public.calendar_events for each row execute function private.guard_event();

create function private.my_calendar_events(event uuid default null) returns setof jsonb language sql stable security definer set search_path='' as $$
 select case when private.can_manage_event(e.team_id,e.technical_details,e.created_by) then to_jsonb(e)
 else to_jsonb(e)||jsonb_build_object('attendees',coalesce((select jsonb_agg(a) from jsonb_array_elements(e.attendees) a where a->>'id'=auth.uid()::text),'[]'::jsonb)) end
 from public.calendar_events e where (event is null or e.id=event) and
 (private.can_manage_event(e.team_id,e.technical_details,e.created_by) or private.can_attend_event(e)) order by e.date,e.id;
$$;
create function public.my_calendar_events(event uuid default null) returns setof jsonb language sql security invoker set search_path='' as $$select private.my_calendar_events(event);$$;
create function private.update_my_event_attendee(event uuid,patch jsonb) returns void language plpgsql security definer set search_path='' as $$
declare e public.calendar_events; a jsonb; clean jsonb; result jsonb:='[]'; found_self boolean:=false;
begin
 select * into e from public.calendar_events where id=event for update;
 if e.id is null or not private.can_attend_event(e) then raise exception 'Convocazione non autorizzata' using errcode='42501'; end if;
 select coalesce(jsonb_object_agg(key,value),'{}') into clean from jsonb_each(patch) where key=any(array['attendanceStatus','isPresent','respondedAt','laps','freeLaps','freeChanges','freeLapsBySpecialty','freeChangesBySpecialty','trackLaps','trackGates','trainingLaps','trainingBlockLaps','trainingBlockReferences','rpe','pain','chronoNotes','athleteNotes','actualDrylandDetails']);
 clean:=clean||jsonb_build_object('id',auth.uid(),'modifiedByAthlete',true,'modifiedAt',now());
 for a in select value from jsonb_array_elements(coalesce(e.attendees,'[]')) loop
   if a->>'id'=auth.uid()::text then a:=a||clean; found_self:=true; end if;
   result:=result||jsonb_build_array(a);
 end loop;
 if not found_self then result:=result||jsonb_build_array(clean); end if;
 update public.calendar_events set attendees=result where id=event;
end $$;
create function public.update_my_event_attendee(event uuid,patch jsonb) returns void language sql security invoker set search_path='' as $$select private.update_my_event_attendee(event,patch);$$;

create function private.guard_session() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and new.user_id is distinct from old.user_id then raise exception 'Proprietario immutabile' using errcode='42501'; end if;
 if new.event_id is not null and not exists(select 1 from public.calendar_events e where e.id=new.event_id and
   (private.can_manage_event(e.team_id,e.technical_details,e.created_by) or (new.user_id=auth.uid() and private.can_attend_event(e)))
   and (jsonb_array_length(coalesce(e.attendees,'[]'))=0 or exists(select 1 from jsonb_array_elements(e.attendees) a where a->>'id'=new.user_id::text))) then
   raise exception 'Allenamento collegato non autorizzato' using errcode='42501'; end if;
 return new;
end $$;
create trigger guard_session before insert or update on public.training_sessions for each row execute function private.guard_session();

create function private.sync_pr_max() returns trigger language plpgsql security definer set search_path='' as $$
declare u uuid; ex text; maximum numeric;
begin
 if tg_op='DELETE' then u:=old.user_id;ex:=old.exercise_id;else u:=new.user_id;ex:=new.exercise_id; end if;
 perform 1 from public.profiles where id=u for update;
 select max(weight) into maximum from public.pr_logs where user_id=u and exercise_id=ex;
 update public.profiles set one_rep_max=case when maximum is null then coalesce(one_rep_max,'{}')-ex else jsonb_set(coalesce(one_rep_max,'{}'),array[ex],to_jsonb(maximum)) end where id=u;
 if tg_op='UPDATE' and old.exercise_id is distinct from new.exercise_id then
   select max(weight) into maximum from public.pr_logs where user_id=u and exercise_id=old.exercise_id;
   update public.profiles set one_rep_max=case when maximum is null then coalesce(one_rep_max,'{}')-old.exercise_id else jsonb_set(coalesce(one_rep_max,'{}'),array[old.exercise_id],to_jsonb(maximum)) end where id=u;
 end if;
 return null;
end $$;
create trigger sync_pr_max after insert or update or delete on public.pr_logs for each row execute function private.sync_pr_max();

-- Notification contents and recipients are generated from a validated event.
alter table public.notifications add column event_id uuid references public.calendar_events(id) on delete cascade;
create function private.notify_event() returns trigger language plpgsql security definer set search_path='' as $$
declare a jsonb;
begin
 if tg_op='UPDATE' and (to_jsonb(new)-'attendees')=(to_jsonb(old)-'attendees') then return null; end if;
 if new.date<current_date and new.status<>'cancelled' then return null; end if;
 for a in select value from jsonb_array_elements(coalesce(new.attendees,'[]')) loop
   insert into public.notifications(user_id,title,message,timestamp,type,is_read,event_id)
   values((a->>'id')::uuid,case when new.status='cancelled' then 'Allenamento annullato' else 'Allenamento aggiornato' end,
     new.title||' — '||new.date::text||' alle '||new.start_time::text,now(),'training',false,new.id);
 end loop;
 return null;
end $$;
create trigger notify_event after insert or update on public.calendar_events for each row execute function private.notify_event();

-- Clear previous broad grants/policies, then grant the operations actually used.
do $$declare tab text; pol record;begin
 foreach tab in array array['profiles','teams','training_sessions','body_metric_logs','pr_logs','jump_logs','calendar_events','notifications','hrv_baselines'] loop
  execute format('alter table public.%I enable row level security',tab);
  execute format('revoke all on public.%I from public,anon,authenticated',tab);
  for pol in select policyname from pg_policies where schemaname='public' and tablename=tab loop execute format('drop policy %I on public.%I',pol.policyname,tab);end loop;
 end loop;
end $$;
grant select,insert,update on public.profiles to authenticated;
grant select(id,name,category,image,members,description,is_private) on public.teams to authenticated;
grant select,insert,update,delete on public.training_sessions,public.body_metric_logs,public.pr_logs,public.jump_logs,public.calendar_events,public.hrv_baselines to authenticated;
grant select,delete on public.notifications to authenticated;
grant update(is_read) on public.notifications to authenticated;
create policy profiles_read on public.profiles for select to authenticated using(id=(select auth.uid()) or private.can_coach(id));
create policy profiles_insert on public.profiles for insert to authenticated with check(id=(select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy teams_read on public.teams for select to authenticated using(private.is_member(id));
do $$declare tab text;begin
 foreach tab in array array['body_metric_logs','hrv_baselines','pr_logs','jump_logs','training_sessions'] loop
  execute format('create policy %I on public.%I for select to authenticated using(user_id=(select auth.uid()) or private.can_coach(user_id))',tab||'_read',tab);
 end loop;
 foreach tab in array array['body_metric_logs','hrv_baselines'] loop
  execute format('create policy %I on public.%I for insert to authenticated with check(user_id=(select auth.uid()))',tab||'_insert',tab);
  execute format('create policy %I on public.%I for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()))',tab||'_update',tab);
  execute format('create policy %I on public.%I for delete to authenticated using(user_id=(select auth.uid()))',tab||'_delete',tab);
 end loop;
 foreach tab in array array['pr_logs','jump_logs'] loop
  execute format('create policy %I on public.%I for insert to authenticated with check(user_id=(select auth.uid()) or private.can_coach(user_id))',tab||'_insert',tab);
  execute format('create policy %I on public.%I for update to authenticated using(user_id=(select auth.uid()) or private.can_coach(user_id)) with check(user_id=(select auth.uid()) or private.can_coach(user_id))',tab||'_update',tab);
  execute format('create policy %I on public.%I for delete to authenticated using(user_id=(select auth.uid()) or private.can_coach(user_id))',tab||'_delete',tab);
 end loop;
end $$;
create policy session_insert on public.training_sessions for insert to authenticated with check(user_id=(select auth.uid()) or (private.can_coach(user_id) and coalesce(details->>'source','') not in ('health_sync','imported')));
create policy session_update on public.training_sessions for update to authenticated using(user_id=(select auth.uid()) or (private.can_coach(user_id) and coalesce(details->>'source','') not in ('health_sync','imported'))) with check(user_id=(select auth.uid()) or (private.can_coach(user_id) and coalesce(details->>'source','') not in ('health_sync','imported')));
create policy session_delete on public.training_sessions for delete to authenticated using(user_id=(select auth.uid()) or (private.can_coach(user_id) and coalesce(details->>'source','') not in ('health_sync','imported')));
create policy events_read on public.calendar_events for select to authenticated using(private.can_manage_event(team_id,technical_details,created_by));
create policy events_insert on public.calendar_events for insert to authenticated with check(created_by=(select auth.uid()) and private.can_manage_event(team_id,technical_details,created_by));
create policy events_update on public.calendar_events for update to authenticated using(private.can_manage_event(team_id,technical_details,created_by)) with check(private.can_manage_event(team_id,technical_details,created_by));
create policy events_delete on public.calendar_events for delete to authenticated using(private.can_manage_event(team_id,technical_details,created_by));
create policy notifications_read on public.notifications for select to authenticated using(user_id=(select auth.uid()));
create policy notifications_update on public.notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy notifications_delete on public.notifications for delete to authenticated using(user_id=(select auth.uid()));

-- Sports test results share the legacy metric table; physical/device/wellness
-- readings remain owner-writable only. Whitelist, never arbitrary metric names.
create function private.is_sports_test(metric text) returns boolean language sql immutable set search_path='' as $$
 select metric=any(array['sprint_20m','sprint_60m','balance_bipedal','balance_single_l','balance_single_r','plank_front','plank_side_l','plank_side_r','pullups_max','leger_vam','leger_vo2max','leger_distance']);
$$;
create policy sports_test_insert on public.body_metric_logs for insert to authenticated with check(private.can_coach(user_id) and private.is_sports_test(type));
create policy sports_test_update on public.body_metric_logs for update to authenticated using(private.can_coach(user_id) and private.is_sports_test(type)) with check(private.can_coach(user_id) and private.is_sports_test(type));
create policy sports_test_delete on public.body_metric_logs for delete to authenticated using(private.can_coach(user_id) and private.is_sports_test(type));

-- Leaderboards return totals only. No workout payload, health readings, location,
-- notes, raw HR samples, personal identifiers or invitation responses leave here.
create function private.n(v jsonb) returns numeric language sql immutable set search_path='' as $$
 select case when v#>>'{}' ~ '^[0-9]+([.][0-9]+)?$' then least((v#>>'{}')::numeric,1000000000) else 0 end;
$$;
create function private.arr(v jsonb) returns jsonb language sql immutable set search_path='' as $$select case when jsonb_typeof(v)='array' then v else '[]'::jsonb end;$$;
create function private.specialty(v text) returns text language sql immutable set search_path='' as $$
 select case when upper(v) like '%SL%' then 'SL' when upper(v) like '%GS%' or upper(v) like '%GIGANTE%' then 'GS'
 when upper(v) like '%SG%' or upper(v) like '%SUPER%' then 'SG' when upper(v) like '%DH%' or upper(v) like '%DISCESA%' then 'DH'
 when upper(v) like '%SX%' or upper(v) like '%CROSS%' then 'SX' else coalesce(nullif(upper(v),''),'CL') end;
$$;
create function private.event_actual(d jsonb,a jsonb,sport text) returns jsonb language plpgsql immutable set search_path='' as $$
declare result jsonb:=coalesce(d,'{}'); items jsonb; b jsonb; id text; k text;
begin
 if sport<>'ski' then
   return coalesce(a->'actualDrylandDetails',d->'plannedDrylandSession','{}'::jsonb);
 end if;
 foreach k in array array['tracks','trainingBlocks'] loop
   items:='[]';
   for b in select value from jsonb_array_elements(private.arr(d->k)) loop
     id:=b->>'id';
     if k='tracks' then
       b:=b||jsonb_strip_nulls(jsonb_build_object('laps',a->'trackLaps'->id,'gates',a->'trackGates'->id));
     else b:=b||jsonb_strip_nulls(jsonb_build_object('laps',a->'trainingBlockLaps'->id,'references',a->'trainingBlockReferences'->id)); end if;
     items:=items||jsonb_build_array(b);
   end loop;
   if items<>'[]'::jsonb then result:=jsonb_set(result,array[k],items); end if;
 end loop;
 items:='{}';
 if jsonb_typeof(d->'freeSkiingBySpecialty')='object' then
   for k,b in select key,value from jsonb_each(d->'freeSkiingBySpecialty') loop
     items:=items||jsonb_build_object(k,b||jsonb_strip_nulls(jsonb_build_object('laps',a->'freeLapsBySpecialty'->k,'changes',a->'freeChangesBySpecialty'->k)));
   end loop;
   result:=jsonb_set(result,'{freeSkiingBySpecialty}',items);
 end if;
 return result||coalesce((select jsonb_object_agg(key,value) from jsonb_each(a) where key in ('laps','freeLaps','trainingLaps')),'{}');
end $$;
create function private.sport_totals(sport text,duration text,starts time,ends time,d jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare result jsonb:='{}'; specialty text:=private.specialty(coalesce(d->'specialties'->>0,d->>'specialty'));
 b jsonb; ex jsonb; st jsonb; k text; val numeric; dirs numeric:=0; volume numeric:=0; contacts numeric:=0; sets integer:=0;
 seconds numeric:=0; endurance numeric:=0; z23 numeric:=0; z45 numeric:=0; is_endurance boolean; blocks jsonb; free jsonb; tracks jsonb;
begin
 if coalesce(d->>'status','completed') in ('planned','cancelled') then return result; end if;
 sport:=regexp_replace(lower(trim(sport)),'[ -]+','_','g');
 if sport=any(array['alpine_skiing','alpine_ski','downhill_skiing','downhill_ski','ski','skiing','snow_sports','snow_sport','snowsports','snowboarding']) then
   free:=case when jsonb_typeof(d->'freeSkiingBySpecialty')='object' and d->'freeSkiingBySpecialty'<>'{}'::jsonb then d->'freeSkiingBySpecialty' else jsonb_build_object(specialty,coalesce(d->'freeSkiing','{}')) end;
   for k,b in select key,value from jsonb_each(free) loop
     dirs:=dirs+private.n(case when (select count(*) from jsonb_each(free))=1 then coalesce(d->'freeLaps',b->'laps') else b->'laps' end)*private.n(b->'changes');
   end loop;
   tracks:=private.arr(d->'tracks');
   if tracks='[]'::jsonb and jsonb_typeof(d->'gatedSkiing')='object' then tracks:=jsonb_build_array(d->'gatedSkiing'||jsonb_strip_nulls(jsonb_build_object('laps',d->'laps'))); end if;
   for b in select value from jsonb_array_elements(tracks) loop
     k:=private.specialty(coalesce(b->>'specialty',specialty));
     val:=private.n(b->'laps')*private.n(coalesce(b->'gates',b->'changes')); dirs:=dirs+val;
     result:=result||jsonb_build_object(k,private.n(result->k)+val);
   end loop;
   blocks:=private.arr(d->'trainingBlocks');
   if blocks='[]'::jsonb and jsonb_typeof(d->'addestramento')='object' then blocks:=jsonb_build_array(d->'addestramento'||jsonb_strip_nulls(jsonb_build_object('laps',d->'trainingLaps'))); end if;
   for b in select value from jsonb_array_elements(blocks) loop dirs:=dirs+private.n(b->'laps')*private.n(coalesce(b->'references',b->'changes')); end loop;
   return result||jsonb_build_object('totalDirectionChanges',dirs);
 end if;
 if duration ~ '^[0-9]+:[0-9]+' then seconds:=(split_part(duration,':',1)::numeric*60+split_part(duration,':',2)::numeric)*60;
 elsif duration ~ '^[0-9]+h' then seconds:=(private.n(to_jsonb(split_part(duration,'h',1))) *60 + private.n(to_jsonb(trim(replace(split_part(duration,'h',2),'m','')))))*60;
 else seconds:=private.n(to_jsonb(regexp_replace(duration,'[^0-9]','','g')))*60; end if;
 if seconds=0 then seconds:=coalesce(nullif(private.n(d->'actualDurationMinutes'),0),nullif(private.n(d->'actual'->'durationMinutes'),0),nullif(private.n(d->'total_duration_minutes'),0),nullif(private.n(d->'active_duration_minutes'),0),nullif(round(private.n(d->'active_duration_seconds')/60),0),mod((extract(epoch from ends-starts)::numeric/60)+1440,1440))*60; end if;
 blocks:=private.arr(d->'blocks');
 if blocks='[]'::jsonb and jsonb_typeof(d->'exercises')='array' then blocks:=jsonb_build_array(jsonb_build_object('type','strength','exercises',d->'exercises')); end if;
 for b in select value from jsonb_array_elements(blocks) loop
   if b->>'type'='strength' and coalesce(d->>'activityCategory','')<>'plyometrics' then
     for ex in select value from jsonb_array_elements(private.arr(b->'exercises')) loop
       for st in select value from jsonb_array_elements(private.arr(ex->'sets')) loop
         if private.n(st->'kg')>0 or private.n(st->'reps')>0 then sets:=sets+1; volume:=volume+private.n(st->'kg')*private.n(st->'reps'); end if;
       end loop;
     end loop;
   elsif b->>'type'='plyometrics' then
     for ex in select value from jsonb_array_elements(private.arr(b->'plyometrics')) loop
       for st in select value from jsonb_array_elements(private.arr(ex->'sets')) loop contacts:=contacts+private.n(coalesce(st->'contacts',st->'reps')); end loop;
     end loop;
     if private.arr(b->'plyometrics')='[]'::jsonb then
       for st in select value from jsonb_array_elements(private.arr(b->'metrics'->'sets')) loop contacts:=contacts+private.n(coalesce(st->'contacts',st->'reps')); end loop;
     end if;
   elsif b->>'type'='endurance' then
     endurance:=endurance+private.n(b->'endurance'->'durationSeconds');
     z23:=z23+private.n(b->'endurance'->'zone23Seconds');z45:=z45+private.n(b->'endurance'->'zone45Seconds');
   end if;
 end loop;
 is_endurance:=d->>'activityCategory'='endurance' or sport ~ '(running|cycling|endurance|resistenza|aerobic|cardio)' or sport=any(array['swimming','rowing','hiking','walking','cross_country_skiing','triathlon','track_field','track_and_field','marathon','mountain_biking','spinning']) or endurance>0 or z23+z45>0;
 if is_endurance then
   if endurance=0 then endurance:=seconds; end if;
   if z23+z45=0 then
     if jsonb_array_length(private.arr(d->'hr_zones_seconds'))>=6 then
       z23:=private.n(d->'hr_zones_seconds'->2)+private.n(d->'hr_zones_seconds'->3); z45:=private.n(d->'hr_zones_seconds'->4)+private.n(d->'hr_zones_seconds'->5);
     else z23:=(private.n(d->'hr_zones'->1)+private.n(d->'hr_zones'->2))*60;z45:=(private.n(d->'hr_zones'->3)+private.n(d->'hr_zones'->4))*60; end if;
   end if;
 end if;
 return jsonb_build_object('hoursOutsideAlpineSki',seconds/3600,'strengthVolumeKg',volume,'strengthSessions',case when sets>0 then 1 else 0 end,'plyometricContacts',contacts,
 'enduranceHours',least(endurance,case when seconds>0 then seconds else endurance end)/3600,'zone23Hours',z23/3600,'zone45Hours',z45/3600,'enduranceSessions',case when is_endurance then 1 else 0 end);
end $$;
create function private.team_leaderboard(t uuid,starts date,ends date) returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_member(t) then raise exception 'Squadra non autorizzata' using errcode='42501'; end if;
 if ends<starts or ends-starts>400 then raise exception 'Periodo non valido'; end if;
 return query
 with athletes as (select p.id from public.team_memberships m join public.profiles p on p.id=m.user_id where m.team_id=t and m.status='active' and m.role='athlete'),
 metrics as (
   select s.user_id,private.sport_totals(s.sport_id,s.duration,s.start_time,s.end_time,s.details) totals from public.training_sessions s join athletes a on a.id=s.user_id where s.date>=starts and s.date<ends
   union all
   select a.id,private.sport_totals(case when e.sport_category='ski' then 'alpine_skiing' else coalesce(e.technical_details->'plannedDrylandSession'->>'sportType','dryland_'||coalesce(e.dryland_specialty,'other')) end,
     ((extract(epoch from e.end_time-e.start_time)::numeric/60+1440)::integer%1440)::text,e.start_time,e.end_time,private.event_actual(e.technical_details,inv.value,e.sport_category))
   from public.calendar_events e cross join lateral jsonb_array_elements(coalesce(e.attendees,'[]')) inv join athletes a on inv.value->>'id'=a.id::text
   where e.status='completed' and e.date>=starts and e.date<ends and t in(select private.event_teams(e.team_id,e.technical_details))
     and (inv.value->>'attendanceStatus'='present' or inv.value->>'isPresent'='true')
     and not exists(select 1 from public.training_sessions s where s.user_id=a.id and s.event_id=e.id)
 ), totals as (select user_id,k.key,sum(private.n(k.value)) val from metrics cross join lateral jsonb_each(totals) k group by user_id,k.key)
 select jsonb_build_object('id',a.id,'values',coalesce((select jsonb_object_agg(key,val) from totals where user_id=a.id),'{}')) from athletes a;
end $$;
create function public.team_leaderboard(t uuid,starts date,ends date) returns setof jsonb language sql security invoker set search_path='' as $$select private.team_leaderboard(t,starts,ends);$$;

create index profiles_team_idx on public.profiles(team_id);
create index training_sessions_user_date_idx on public.training_sessions(user_id,date);
create index training_sessions_event_idx on public.training_sessions(event_id);
create index body_metric_logs_user_date_idx on public.body_metric_logs(user_id,date);
create index pr_logs_user_exercise_idx on public.pr_logs(user_id,exercise_id);
create index jump_logs_user_date_idx on public.jump_logs(user_id,date);
create index calendar_events_team_idx on public.calendar_events(team_id);
create index calendar_events_creator_idx on public.calendar_events(created_by);
create index notifications_user_idx on public.notifications(user_id);
create index notifications_event_idx on public.notifications(event_id);

-- Profile images are private. Paths use the authenticated account UUID prefix.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('avatars','avatars',false,5242880,array['image/jpeg','image/png','image/webp']);
create function private.can_view_avatar(owner_id text) returns boolean language sql stable security definer set search_path='' as $$
 select owner_id=auth.uid()::text or exists(select 1 from public.team_memberships a join public.team_memberships b on a.team_id=b.team_id
 where a.user_id::text=owner_id and a.status='active' and b.user_id=auth.uid() and b.status='active');
$$;
create policy avatars_read on storage.objects for select to authenticated using(bucket_id='avatars' and private.can_view_avatar((storage.foldername(name))[1]));
create policy avatars_insert on storage.objects for insert to authenticated with check(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy avatars_update on storage.objects for update to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy avatars_delete on storage.objects for delete to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);

revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on function private.is_member(uuid),private.is_coach(uuid),private.is_manager(uuid),private.can_coach(uuid),private.event_teams(uuid,jsonb),private.can_manage_event(uuid,jsonb,uuid),private.can_attend_event(public.calendar_events),private.can_view_avatar(text),private.valid_event_attendee(uuid,uuid,jsonb),private.is_sports_test(text) to authenticated;
grant execute on function private.team_leaderboard(uuid,date,date) to authenticated;
revoke execute on function public.team_leaderboard(uuid,date,date) from public,anon;
grant execute on function public.team_leaderboard(uuid,date,date) to authenticated;
grant execute on function private.team_operation(text,uuid,uuid,jsonb),private.get_my_teams(),private.team_directory(uuid,boolean),private.my_calendar_events(uuid),private.update_my_event_attendee(uuid,jsonb) to authenticated;
revoke execute on function public.team_operation(text,uuid,uuid,jsonb),public.get_my_teams(),public.team_directory(uuid,boolean),public.my_calendar_events(uuid),public.update_my_event_attendee(uuid,jsonb) from public,anon;
grant execute on function public.team_operation(text,uuid,uuid,jsonb),public.get_my_teams(),public.team_directory(uuid,boolean),public.my_calendar_events(uuid),public.update_my_event_attendee(uuid,jsonb) to authenticated;
