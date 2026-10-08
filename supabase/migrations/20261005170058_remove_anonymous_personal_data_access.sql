revoke all privileges on table public.profiles, public.teams, public.training_sessions,
public.body_metric_logs, public.pr_logs, public.jump_logs, public.calendar_events,
public.notifications, public.hrv_baselines from anon;
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;
