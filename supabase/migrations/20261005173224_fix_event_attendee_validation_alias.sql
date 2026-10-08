create or replace function private.guard_event() returns trigger language plpgsql set search_path='' as $$
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
 if (select count(*) from jsonb_array_elements(coalesce(new.attendees,'[]'))) <> (select count(distinct invited.value->>'id') from jsonb_array_elements(coalesce(new.attendees,'[]')) invited) then raise exception 'Inviti duplicati'; end if;
 return new;
end $$;
