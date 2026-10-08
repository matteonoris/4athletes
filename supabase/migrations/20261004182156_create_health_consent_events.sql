create table public.health_consent_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 decision text not null check (decision in ('granted','declined','revoked')),
 notice_version text not null check (notice_version = '2026-10-04'),
 recorded_at timestamptz not null default now()
);
create index health_consent_events_user_latest_idx on public.health_consent_events(user_id, id desc);
alter table public.health_consent_events enable row level security;
revoke all on public.health_consent_events from public, anon, authenticated;
grant select on public.health_consent_events to authenticated;
grant insert (user_id, decision, notice_version) on public.health_consent_events to authenticated;
grant usage on sequence public.health_consent_events_id_seq to authenticated;
create policy health_consent_read_own on public.health_consent_events for select to authenticated using ((select auth.uid()) = user_id);
create policy health_consent_record_own on public.health_consent_events for insert to authenticated with check ((select auth.uid()) = user_id);
comment on table public.health_consent_events is 'Append-only service health-import choices; server time; not research consent.';
