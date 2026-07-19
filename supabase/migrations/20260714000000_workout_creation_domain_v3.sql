-- Additive workout-domain v3 migration.
-- Existing training_sessions and calendar_events remain authoritative. Their
-- JSONB payloads are read through the backwards-compatible Dart mapper, so no
-- destructive rewrite of historical workouts is required.

alter table if exists public.workout_templates
  add column if not exists activity_mode text,
  add column if not exists protocol_id text,
  add column if not exists structure_mode text not null default 'simple',
  add column if not exists planned_duration_minutes integer,
  add column if not exists visibility text not null default 'private';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'workout_templates_structure_mode_check'
  ) then
    alter table public.workout_templates
      add constraint workout_templates_structure_mode_check
      check (structure_mode in ('simple', 'phased'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'workout_templates_duration_check'
  ) then
    alter table public.workout_templates
      add constraint workout_templates_duration_check
      check (
        planned_duration_minutes is null
        or planned_duration_minutes > 0
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'workout_templates_visibility_check'
  ) then
    alter table public.workout_templates
      add constraint workout_templates_visibility_check
      check (visibility in ('private', 'team'));
  end if;
end
$$;

create index if not exists workout_templates_protocol_idx
  on public.workout_templates(protocol_id)
  where protocol_id is not null and is_archived = false;

comment on column public.workout_templates.activity_mode is
  'How the activity is organized, distinct from the activity and protocol.';
comment on column public.workout_templates.protocol_id is
  'Optional reusable protocol identifier, for example norwegian_4x4.';
comment on column public.workout_templates.structure_mode is
  'simple uses only main work; phased supports warmup, main and cooldown.';

-- Historical mapping is deliberately performed lazily by WorkoutLegacyMapper:
-- forza -> dryland_strength
-- pliometria -> dryland_plyometrics
-- velocita/agilita -> dryland_speed_agility
-- mobilita/core -> mobility_recovery
-- misto/circuito -> conditioning_hiit
-- resistenza -> associated sport when known, otherwise other while preserving
--                the original value in legacyActivityType.
