-- System catalogue for speed and agility work. The client keeps an offline
-- copy of the same IDs in lib/data/exercises.dart.
-- Reference families:
-- - World Athletics, The Sprints / Introduction to Sprinting
-- - NSCA, Developing Speed and Developing Agility and Quickness excerpts

create table if not exists public.speed_agility_exercises (
  id text primary key,
  name text not null,
  exercise_group text not null,
  equipment_category text not null default 'bodyweight',
  tracking_schema text not null default 'speed_trials_v1',
  default_trials integer not null default 4,
  default_distance_m numeric,
  default_rest_seconds integer,
  aliases text[] not null default '{}',
  source_family text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint speed_agility_exercises_trials_check
    check (default_trials > 0),
  constraint speed_agility_exercises_distance_check
    check (default_distance_m is null or default_distance_m > 0),
  constraint speed_agility_exercises_rest_check
    check (default_rest_seconds is null or default_rest_seconds >= 0)
);

alter table public.speed_agility_exercises enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'speed_agility_exercises'
      and policyname = 'speed_agility_exercises_authenticated_read'
  ) then
    create policy "speed_agility_exercises_authenticated_read"
      on public.speed_agility_exercises
      for select
      to authenticated
      using (is_active = true);
  end if;
end
$$;

grant select on public.speed_agility_exercises to authenticated;

insert into public.speed_agility_exercises (
  id, name, exercise_group, equipment_category, default_trials,
  default_distance_m, default_rest_seconds, aliases, source_family, sort_order
)
values
  ('sprint', 'Sprint (Accelerazioni)', 'Accelerazione', 'bodyweight', 4, 20, 120, array['scatti','accelerazioni'], 'world_athletics_sprints', 5),
  ('speed_wall_march', 'Wall Drill March', 'Tecnica di corsa', 'bodyweight', 2, 10, 45, array['marcia al muro','wall drill'], 'world_athletics_sprints', 10),
  ('speed_wall_switch', 'Wall Drill Switch', 'Tecnica di corsa', 'bodyweight', 3, 10, 45, array['cambio al muro','wall switch'], 'world_athletics_sprints', 20),
  ('speed_ankling', 'Ankling', 'Tecnica di corsa', 'bodyweight', 2, 20, 45, array['corsa di caviglia','sprint abc'], 'world_athletics_sprints', 30),
  ('speed_a_march', 'A-March', 'Tecnica di corsa', 'bodyweight', 2, 20, 45, array['marcia a','sprint abc'], 'world_athletics_sprints', 40),
  ('speed_a_skip', 'A-Skip', 'Tecnica di corsa', 'bodyweight', 2, 20, 45, array['skip a','sprint abc'], 'world_athletics_sprints', 50),
  ('speed_b_skip', 'B-Skip', 'Tecnica di corsa', 'bodyweight', 2, 20, 45, array['skip b','sprint abc'], 'world_athletics_sprints', 60),
  ('speed_dribble_run', 'Dribble Run', 'Tecnica di corsa', 'bodyweight', 3, 20, 60, array['dribble basso','corsa rapida'], 'world_athletics_sprints', 70),
  ('speed_straight_leg_run', 'Straight-Leg Run', 'Tecnica di corsa', 'bodyweight', 2, 20, 60, array['corsa gambe tese'], 'world_athletics_sprints', 80),
  ('speed_fast_leg', 'Fast Leg Drill', 'Tecnica di corsa', 'bodyweight', 3, 20, 60, array['gamba rapida'], 'world_athletics_sprints', 90),
  ('speed_falling_start', 'Falling Start Sprint', 'Accelerazione', 'bodyweight', 4, 20, 120, array['partenza in caduta'], 'world_athletics_sprints', 100),
  ('speed_two_point_start', 'Sprint da partenza a 2 appoggi', 'Accelerazione', 'bodyweight', 4, 20, 120, array['2 point start','partenza in piedi'], 'world_athletics_sprints', 110),
  ('speed_three_point_start', 'Sprint da partenza a 3 appoggi', 'Accelerazione', 'bodyweight', 4, 20, 150, array['3 point start'], 'world_athletics_sprints', 120),
  ('speed_block_start', 'Sprint dai blocchi', 'Accelerazione', 'starting_blocks', 4, 30, 180, array['block start','partenza dai blocchi'], 'world_athletics_sprints', 130),
  ('speed_pushup_start', 'Sprint da posizione push-up', 'Accelerazione', 'bodyweight', 4, 15, 90, array['push up start'], 'world_athletics_sprints', 140),
  ('speed_prone_start', 'Sprint da posizione prona', 'Accelerazione', 'bodyweight', 4, 15, 90, array['prone start','partenza a terra'], 'world_athletics_sprints', 150),
  ('speed_half_kneeling_start', 'Sprint da mezzo inginocchiato', 'Accelerazione', 'bodyweight', 4, 15, 90, array['half kneeling start'], 'world_athletics_sprints', 160),
  ('speed_rolling_start', 'Sprint con partenza lanciata', 'Accelerazione', 'bodyweight', 4, 30, 150, array['rolling start'], 'world_athletics_sprints', 170),
  ('speed_hill_sprint', 'Sprint in salita', 'Accelerazione resistita', 'bodyweight', 5, 20, 150, array['hill sprint','scatto in salita'], 'world_athletics_sprints', 180),
  ('speed_sled_sprint', 'Sprint con slitta', 'Accelerazione resistita', 'sled', 5, 20, 150, array['sled sprint','slitta trainata'], 'world_athletics_sprints', 190),
  ('speed_band_resisted_sprint', 'Sprint con elastico resistito', 'Accelerazione resistita', 'band', 5, 15, 120, array['band resisted sprint'], 'world_athletics_sprints', 200),
  ('speed_partner_resisted_sprint', 'Sprint resistito dal partner', 'Accelerazione resistita', 'partner', 5, 15, 120, array['partner resisted sprint'], 'world_athletics_sprints', 210),
  ('speed_flying_10', 'Flying Sprint 10 m', 'Velocita massima', 'cones', 4, 10, 180, array['flying 10','lanciato 10'], 'world_athletics_sprints', 220),
  ('speed_flying_20', 'Flying Sprint 20 m', 'Velocita massima', 'cones', 4, 20, 240, array['flying 20','lanciato 20'], 'world_athletics_sprints', 230),
  ('speed_flying_30', 'Flying Sprint 30 m', 'Velocita massima', 'cones', 3, 30, 300, array['flying 30','lanciato 30'], 'world_athletics_sprints', 240),
  ('speed_wicket_run', 'Wicket Run', 'Velocita massima', 'mini_hurdles', 4, 30, 180, array['wickets','ostacolini ritmici'], 'world_athletics_sprints', 250),
  ('speed_ins_and_outs', 'Ins and Outs', 'Velocita massima', 'cones', 4, 60, 240, array['sprint alternato veloce rilassato'], 'world_athletics_sprints', 260),
  ('speed_build_up_40', 'Build-Up Sprint 40 m', 'Velocita massima', 'cones', 4, 40, 180, array['progressivo 40'], 'world_athletics_sprints', 270),
  ('speed_sprint_60', 'Sprint 60 m', 'Speed endurance', 'bodyweight', 4, 60, 300, array['scatto 60'], 'world_athletics_sprints', 280),
  ('speed_sprint_80', 'Sprint 80 m', 'Speed endurance', 'bodyweight', 3, 80, 360, array['scatto 80'], 'world_athletics_sprints', 290),
  ('speed_sprint_120', 'Sprint 120 m', 'Speed endurance', 'bodyweight', 3, 120, 480, array['scatto 120'], 'world_athletics_sprints', 300),
  ('speed_sprint_150', 'Sprint 150 m', 'Speed endurance', 'bodyweight', 3, 150, 480, array['scatto 150'], 'world_athletics_sprints', 310),
  ('speed_repeated_sprint_30', 'Repeated Sprint 30 m', 'Speed endurance', 'cones', 6, 30, 30, array['rsa 30','sprint ripetuti'], 'world_athletics_sprints', 320),
  ('speed_sprint_to_stick', 'Sprint to Stick', 'Decelerazione', 'cones', 4, 15, 90, array['sprint e arresto','stop controllato'], 'nsca_agility', 330),
  ('speed_deceleration_zone', 'Decelerazione in zona', 'Decelerazione', 'cones', 4, 20, 90, array['deceleration zone','zona di frenata'], 'nsca_agility', 340),
  ('speed_run_cut_45', 'Run and Cut 45 gradi', 'Cambio di direzione', 'cones', 4, 10, 90, array['taglio 45','cut 45'], 'nsca_agility', 350),
  ('speed_run_cut_90', 'Run and Cut 90 gradi', 'Cambio di direzione', 'cones', 4, 10, 120, array['taglio 90','cut 90'], 'nsca_agility', 360),
  ('speed_run_cut_180', 'Cambio di direzione 180 gradi', 'Cambio di direzione', 'cones', 4, 10, 120, array['taglio 180','inversione'], 'nsca_agility', 370),
  ('speed_5_10_5', 'Pro Agility 5-10-5', 'Cambio di direzione', 'cones', 4, 20, 150, array['5 10 5','pro agility','shuttle laterale'], 'nsca_agility', 380),
  ('speed_505', '505 Agility Test / Drill', 'Cambio di direzione', 'cones', 4, 15, 150, array['5-0-5','505 test'], 'nsca_agility', 390),
  ('speed_t_drill', 'T-Drill', 'Cambio di direzione', 'cones', 3, 36.6, 180, array['test a t','t test'], 'nsca_agility', 400),
  ('speed_l_drill', 'L-Drill / 3 Cone Drill', 'Cambio di direzione', 'cones', 3, 27.4, 180, array['3 cone drill','test a l'], 'nsca_agility', 410),
  ('speed_illinois_drill', 'Illinois Agility Drill', 'Cambio di direzione', 'cones', 3, 60, 180, array['illinois test'], 'nsca_agility', 420),
  ('speed_four_cone_box', 'Four Cone Box Drill', 'Cambio di direzione', 'cones', 4, 20, 120, array['box drill','quadrato quattro coni'], 'nsca_agility', 430),
  ('speed_zig_zag_cones', 'Zig-Zag tra coni', 'Cambio di direzione', 'cones', 4, 20, 90, array['slalom coni','zig zag'], 'nsca_agility', 440),
  ('speed_lateral_shuffle', 'Lateral Shuffle', 'Movimento multidirezionale', 'cones', 4, 10, 60, array['scivolamenti laterali'], 'nsca_agility', 450),
  ('speed_crossover_run', 'Crossover Run', 'Movimento multidirezionale', 'cones', 4, 15, 60, array['corsa incrociata'], 'nsca_agility', 460),
  ('speed_backpedal', 'Backpedal', 'Movimento multidirezionale', 'cones', 4, 15, 60, array['corsa indietro'], 'nsca_agility', 470),
  ('speed_backpedal_to_sprint', 'Backpedal to Sprint', 'Movimento multidirezionale', 'cones', 4, 20, 90, array['indietro e sprint'], 'nsca_agility', 480),
  ('speed_carioca', 'Carioca / Grapevine', 'Movimento multidirezionale', 'cones', 3, 15, 60, array['grapevine','incroci laterali'], 'nsca_agility', 490),
  ('speed_mirror_drill', 'Mirror Drill', 'Agilita reattiva', 'partner', 5, 10, 60, array['esercizio specchio'], 'nsca_reactive_agility', 500),
  ('speed_coach_point_reaction', 'Sprint su indicazione del coach', 'Agilita reattiva', 'cones', 6, 10, 60, array['coach point','comando direzione'], 'nsca_reactive_agility', 510),
  ('speed_color_call', 'Reazione al colore', 'Agilita reattiva', 'colored_cones', 6, 10, 60, array['color call','coni colorati'], 'nsca_reactive_agility', 520),
  ('speed_audio_cue', 'Cambio direzione su segnale sonoro', 'Agilita reattiva', 'cones', 6, 10, 60, array['auditory cue','segnale vocale'], 'nsca_reactive_agility', 530),
  ('speed_ball_drop_reaction', 'Ball Drop Reaction Sprint', 'Agilita reattiva', 'ball', 6, 8, 60, array['presa palla in caduta'], 'nsca_reactive_agility', 540),
  ('speed_partner_chase', 'Partner Chase Sprint', 'Agilita reattiva', 'partner', 5, 15, 90, array['inseguimento partner'], 'nsca_reactive_agility', 550),
  ('speed_reactive_5_10_5', '5-10-5 reattivo', 'Agilita reattiva', 'cones', 4, 20, 150, array['reactive pro agility'], 'nsca_reactive_agility', 560),
  ('speed_reactive_y_drill', 'Reactive Y Drill', 'Agilita reattiva', 'cones', 5, 15, 90, array['y drill reattivo'], 'nsca_reactive_agility', 570),
  ('speed_partner_tag', 'Partner Tag Drill', 'Agilita reattiva', 'partner', 5, 10, 60, array['acchiapparella','tag game'], 'nsca_reactive_agility', 580),
  ('speed_ladder_one_in', 'Scaletta: un appoggio per spazio', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['ladder one in'], 'nsca_line_drills', 590),
  ('speed_ladder_two_in', 'Scaletta: due appoggi per spazio', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['ladder two in'], 'nsca_line_drills', 600),
  ('speed_ladder_icky_shuffle', 'Scaletta: Icky Shuffle', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['icky shuffle'], 'nsca_line_drills', 610),
  ('speed_ladder_in_out', 'Scaletta: In-Out', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['ladder in out'], 'nsca_line_drills', 620),
  ('speed_ladder_lateral_two_in', 'Scaletta: due appoggi laterali', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['lateral two in'], 'nsca_line_drills', 630),
  ('speed_ladder_hopscotch', 'Scaletta: Hopscotch', 'Rapidita di piedi', 'agility_ladder', 3, 8, 45, array['campana scaletta'], 'nsca_line_drills', 640),
  ('speed_line_traveling_scissors', 'Traveling Scissors sulla linea', 'Rapidita di piedi', 'line', 3, 10, 45, array['forbici laterali'], 'nsca_line_drills', 650),
  ('speed_quick_feet_line', 'Quick Feet sulla linea', 'Rapidita di piedi', 'line', 4, 10, 45, array['piedi rapidi linea'], 'nsca_line_drills', 660)
on conflict (id) do update set
  name = excluded.name,
  exercise_group = excluded.exercise_group,
  equipment_category = excluded.equipment_category,
  tracking_schema = excluded.tracking_schema,
  default_trials = excluded.default_trials,
  default_distance_m = excluded.default_distance_m,
  default_rest_seconds = excluded.default_rest_seconds,
  aliases = excluded.aliases,
  source_family = excluded.source_family,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

create index if not exists speed_agility_exercises_group_idx
  on public.speed_agility_exercises(exercise_group, sort_order)
  where is_active = true;

comment on table public.speed_agility_exercises is
  'System speed/agility catalogue. Entries use distance/time trial tracking, not strength-load tracking.';
