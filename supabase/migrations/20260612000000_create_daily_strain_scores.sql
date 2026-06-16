create table if not exists public.daily_strain_scores (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  score double precision,
  status text not null,
  confidence double precision not null default 0,
  cardio_score double precision,
  rpe_score double precision,
  external_mechanical_score double precision,
  cardio_load_au double precision,
  rpe_load_au double precision,
  external_mechanical_load_au double precision,
  total_duration_minutes double precision not null default 0,
  session_count integer not null default 0,
  sport_mix jsonb not null default '{}'::jsonb,
  methods jsonb not null default '{}'::jsonb,
  coverage jsonb not null default '{}'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  algorithm_version text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_strain_scores_athlete_date_unique unique (athlete_id, date),
  constraint daily_strain_scores_score_range check (
    score is null or (score >= 0 and score <= 100)
  ),
  constraint daily_strain_scores_confidence_range check (
    confidence >= 0 and confidence <= 1
  )
);

alter table public.daily_strain_scores enable row level security;

create policy "Athletes can read own daily strain scores"
  on public.daily_strain_scores
  for select
  using (auth.uid() = athlete_id);

create policy "Athletes can insert own daily strain scores"
  on public.daily_strain_scores
  for insert
  with check (auth.uid() = athlete_id);

create policy "Athletes can update own daily strain scores"
  on public.daily_strain_scores
  for update
  using (auth.uid() = athlete_id)
  with check (auth.uid() = athlete_id);

create policy "Athletes can delete own daily strain scores"
  on public.daily_strain_scores
  for delete
  using (auth.uid() = athlete_id);

create or replace function public.set_daily_strain_scores_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists daily_strain_scores_set_updated_at
  on public.daily_strain_scores;

create trigger daily_strain_scores_set_updated_at
  before update on public.daily_strain_scores
  for each row
  execute function public.set_daily_strain_scores_updated_at();
