create table if not exists public.workout_templates (
  id text primary key,
  name text not null,
  description text,
  owner_type text not null default 'coach',
  owner_id uuid not null references auth.users(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  category text not null default 'athletic_prep',
  sport_type text,
  blocks jsonb not null default '[]'::jsonb,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_archived boolean not null default false
);

alter table public.workout_templates enable row level security;

create policy "workout_templates_select_owner_or_team"
on public.workout_templates
for select
using (
  owner_id = auth.uid()
  or created_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.team_id = workout_templates.team_id
  )
);

create policy "workout_templates_insert_own"
on public.workout_templates
for insert
with check (owner_id = auth.uid() and created_by = auth.uid());

create policy "workout_templates_update_owner"
on public.workout_templates
for update
using (owner_id = auth.uid() or created_by = auth.uid())
with check (owner_id = auth.uid() or created_by = auth.uid());

create index if not exists workout_templates_owner_idx
  on public.workout_templates(owner_id, is_archived);

create index if not exists workout_templates_team_idx
  on public.workout_templates(team_id, is_archived);
