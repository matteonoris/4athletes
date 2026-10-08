create or replace function private.guard_session() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and new.user_id is distinct from old.user_id then raise exception 'Proprietario immutabile' using errcode='42501'; end if;
 if new.event_id is not null and (tg_op='INSERT' or new.event_id is distinct from old.event_id) and not exists(select 1 from public.calendar_events e where e.id=new.event_id and
   (private.can_manage_event(e.team_id,e.technical_details,e.created_by) or (new.user_id=auth.uid() and private.can_attend_event(e)))
   and (jsonb_array_length(coalesce(e.attendees,'[]'))=0 or exists(select 1 from jsonb_array_elements(e.attendees) a where a->>'id'=new.user_id::text))) then
   raise exception 'Allenamento collegato non autorizzato' using errcode='42501'; end if;
 return new;
end $$;
create or replace function private.notify_event() returns trigger language plpgsql security definer set search_path='' as $$
declare a jsonb;
begin
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
create or replace function private.team_leaderboard(t uuid,starts date,ends date) returns setof jsonb language plpgsql stable security definer set search_path='' as $$
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
     and (inv.value->>'attendanceStatus'='present' or (coalesce(inv.value->>'attendanceStatus','') not in ('present','absent','pending') and inv.value->>'isPresent'='true'))
     and not exists(select 1 from public.training_sessions s where s.user_id=a.id and s.event_id=e.id)
 ), totals as (select user_id,k.key,sum(private.n(k.value)) val from metrics cross join lateral jsonb_each(totals) k group by user_id,k.key)
 select jsonb_build_object('id',a.id,'values',coalesce((select jsonb_object_agg(key,val) from totals where user_id=a.id),'{}')) from athletes a;
end $$;
