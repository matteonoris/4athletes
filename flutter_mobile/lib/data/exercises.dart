class ExerciseDef {
  final String id;
  final String name;
  final String targetMuscle;
  final String
      category; // 'barbell' | 'dumbbell' | 'machine' | 'cable' | 'bodyweight' | 'kettlebell' | 'band'
  final String activityCategory;
  final String? speedGroup;
  final int? defaultTrials;
  final double? defaultDistanceMeters;
  final int? defaultRestSeconds;
  final List<String> aliases;
  // 'strength' | 'core' | 'mobility' | 'plyometrics' |
  // 'speed_agility' | 'endurance'

  const ExerciseDef(
    this.id,
    this.name,
    this.targetMuscle,
    this.category, {
    this.activityCategory = 'strength',
    this.speedGroup,
    this.defaultTrials,
    this.defaultDistanceMeters,
    this.defaultRestSeconds,
    this.aliases = const [],
  });

  const ExerciseDef.speed(
    this.id,
    this.name,
    String group,
    this.category, {
    this.defaultTrials = 4,
    this.defaultDistanceMeters,
    this.defaultRestSeconds = 90,
    this.aliases = const [],
  })  : targetMuscle = group,
        activityCategory = 'speed_agility',
        speedGroup = group;

  bool get usesSpeedAgilityTracking =>
      resolvedActivityCategory == 'speed_agility';

  String get resolvedActivityCategory {
    if (activityCategory != 'strength') return activityCategory;
    final text = '$id $name $targetMuscle'.toLowerCase();
    if (text.contains('jump') ||
        text.contains('hop') ||
        text.contains('bound') ||
        text.contains('balzi') ||
        text.contains('potenza') ||
        id == 'box_jump' ||
        id == 'broad_jump' ||
        id == 'jump_squat' ||
        id == 'lunge_jump') {
      return 'plyometrics';
    }
    if (text.contains('sprint') ||
        text.contains('scatti') ||
        text.contains('accelerazioni') ||
        text.contains('ladder') ||
        text.contains('agility') ||
        id == 'sprint') {
      return 'speed_agility';
    }
    if (text.contains('mobilit') ||
        text.contains('stretch') ||
        id == 'cat_cow' ||
        id == 'inchworm' ||
        id == 'leg_swing') {
      return 'mobility';
    }
    return activityCategory;
  }
}

/// Warm-up and cool-down use the complete catalogue. The selected workout
/// discipline only narrows the main phase.
bool exerciseMatchesTrainingPhase(
  ExerciseDef exercise, {
  required String phase,
  required Set<String> mainPhaseCategories,
}) {
  if (phase != 'main' || mainPhaseCategories.isEmpty) return true;
  return mainPhaseCategories.contains(exercise.resolvedActivityCategory);
}

const List<ExerciseDef> exerciseDatabase = [
  // CARDIO / RISCALDAMENTO / DEFATICAMENTO
  ExerciseDef('treadmill_run', 'Corsa sul tapis roulant',
      'Cardio / Corpo intero', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('treadmill_walk', 'Camminata sul tapis roulant',
      'Cardio / Recupero', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('stationary_bike', 'Cyclette', 'Cardio / Gambe', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('air_bike', 'Air Bike', 'Cardio / Corpo intero', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('rowing_erg', 'Vogatore', 'Cardio / Corpo intero', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('elliptical', 'Ellittica', 'Cardio / Corpo intero', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('stair_climber', 'Stair Climber', 'Cardio / Gambe', 'machine',
      activityCategory: 'endurance'),
  ExerciseDef('easy_jog', 'Corsa blanda', 'Cardio / Corpo intero', 'bodyweight',
      activityCategory: 'endurance'),
  ExerciseDef(
      'easy_walk', 'Camminata di recupero', 'Cardio / Recupero', 'bodyweight',
      activityCategory: 'endurance'),
  ExerciseDef(
      'jump_rope', 'Salto con la corda', 'Cardio / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),

  // ═══════════════════════════════════════
  // PETTO - CHEST
  // ═══════════════════════════════════════
  ExerciseDef('bp', 'Bench Press', 'Petto', 'barbell'),
  ExerciseDef('bp_inc', 'Incline Bench Press', 'Petto Alto', 'barbell'),
  ExerciseDef('bp_dec', 'Decline Bench Press', 'Petto Basso', 'barbell'),
  ExerciseDef('db_bp', 'Dumbbell Bench Press', 'Petto', 'dumbbell'),
  ExerciseDef('db_bp_inc', 'Incline Dumbbell Press', 'Petto Alto', 'dumbbell'),
  ExerciseDef('db_fly', 'Dumbbell Fly', 'Petto', 'dumbbell'),
  ExerciseDef('db_fly_inc', 'Incline Dumbbell Fly', 'Petto Alto', 'dumbbell'),
  ExerciseDef('cable_fly', 'Cable Crossover Fly', 'Petto', 'cable'),
  ExerciseDef('cable_fly_low', 'Cable Low-to-High Fly', 'Petto Alto', 'cable'),
  ExerciseDef(
      'cable_fly_high', 'Cable High-to-Low Fly', 'Petto Basso', 'cable'),
  ExerciseDef('chest_press_m', 'Chest Press Machine', 'Petto', 'machine'),
  ExerciseDef('pec_dec', 'Pec Deck / Butterfly', 'Petto', 'machine'),
  ExerciseDef('pushup', 'Push-Up', 'Petto', 'bodyweight'),
  ExerciseDef('pushup_inc', 'Incline Push-Up', 'Petto Alto', 'bodyweight'),
  ExerciseDef('pushup_dec', 'Decline Push-Up', 'Petto Basso', 'bodyweight'),
  ExerciseDef('pushup_wide', 'Wide-Grip Push-Up', 'Petto', 'bodyweight'),
  ExerciseDef('dips_chest', 'Chest Dips', 'Petto', 'bodyweight'),

  // ═══════════════════════════════════════
  // SPALLE - SHOULDERS
  // ═══════════════════════════════════════
  ExerciseDef('ohp', 'Overhead Press (Barbell)', 'Spalle', 'barbell'),
  ExerciseDef('push_press', 'Push Press', 'Spalle', 'barbell'),
  ExerciseDef('db_ohp', 'Dumbbell Shoulder Press', 'Spalle', 'dumbbell'),
  ExerciseDef('db_lat_raise', 'Lateral Raise', 'Deltoide Lat.', 'dumbbell'),
  ExerciseDef('db_front_raise', 'Front Raise', 'Deltoide Ant.', 'dumbbell'),
  ExerciseDef('db_bent_raise', 'Bent-Over Rear Delt Raise', 'Deltoide Post.',
      'dumbbell'),
  ExerciseDef('cable_lat', 'Cable Lateral Raise', 'Deltoide Lat.', 'cable'),
  ExerciseDef('cable_face_pull', 'Face Pull', 'Deltoide Post.', 'cable'),
  ExerciseDef('cable_fr_raise', 'Cable Front Raise', 'Deltoide Ant.', 'cable'),
  ExerciseDef(
      'shoulder_press_m', 'Shoulder Press Machine', 'Spalle', 'machine'),
  ExerciseDef(
      'rear_delt_m', 'Rear Delt Machine Fly', 'Deltoide Post.', 'machine'),
  ExerciseDef('upright_row', 'Upright Row', 'Trapezio / Sp.', 'barbell'),
  ExerciseDef('db_shrug', 'Dumbbell Shrug', 'Trapezio', 'dumbbell'),
  ExerciseDef('bar_shrug', 'Barbell Shrug', 'Trapezio', 'barbell'),
  ExerciseDef('handstand_pu', 'Handstand Push-Up', 'Spalle', 'bodyweight'),
  ExerciseDef('pike_pushup', 'Pike Push-Up', 'Spalle', 'bodyweight'),

  // ═══════════════════════════════════════
  // SCHIENA - BACK
  // ═══════════════════════════════════════
  ExerciseDef('back_squat', 'Back Squat', 'Quadricipiti', 'barbell'),
  ExerciseDef('deadlift', 'Deadlift', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('sumo_dl', 'Sumo Deadlift', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('bent_row', 'Barbell Bent-Over Row', 'Dorsali', 'barbell'),
  ExerciseDef('pendlay_row', 'Pendlay Row', 'Dorsali', 'barbell'),
  ExerciseDef('db_row', 'Dumbbell Row', 'Dorsali', 'dumbbell'),
  ExerciseDef('db_pullover', 'Dumbbell Pullover', 'Dorsali', 'dumbbell'),
  ExerciseDef('pullup', 'Pull-Up', 'Dorsali', 'bodyweight'),
  ExerciseDef('chinup', 'Chin-Up', 'Dorsali / Bicipiti', 'bodyweight'),
  ExerciseDef(
      'neutral_pullup', 'Neutral-Grip Pull-Up', 'Dorsali', 'bodyweight'),
  ExerciseDef(
      'inverted_row', 'Inverted Row (Bodyweight)', 'Dorsali', 'bodyweight'),
  ExerciseDef(
      'lat_pulldown', 'Lat Pulldown (Presa Larga)', 'Dorsali', 'machine'),
  ExerciseDef(
      'lat_pd_close', 'Lat Pulldown Presa Stretta', 'Dorsali', 'machine'),
  ExerciseDef('seat_row', 'Seated Cable Row', 'Dorsali', 'cable'),
  ExerciseDef(
      'seat_row_wide', 'Seated Cable Row (Presa Larga)', 'Dorsali', 'cable'),
  ExerciseDef('cable_pullover', 'Cable Pullover', 'Dorsali', 'cable'),
  ExerciseDef('tbar_row', 'T-Bar Row', 'Dorsali', 'machine'),
  ExerciseDef(
      'back_ext', 'Back Extension / Hyperextension', 'Lombari', 'machine'),
  ExerciseDef('good_morning', 'Good Morning', 'Lombari', 'barbell'),
  ExerciseDef('superman', 'Superman Hold', 'Lombari', 'bodyweight'),

  // ═══════════════════════════════════════
  // BRACCIA - BICIPITI
  // ═══════════════════════════════════════
  ExerciseDef('barbell_curl', 'Barbell Curl', 'Bicipiti', 'barbell'),
  ExerciseDef('ez_curl', 'EZ-Bar Curl', 'Bicipiti', 'barbell'),
  ExerciseDef('db_curl', 'Dumbbell Curl', 'Bicipiti', 'dumbbell'),
  ExerciseDef(
      'hammer_curl', 'Hammer Curl', 'Bicipiti / Brachiorad.', 'dumbbell'),
  ExerciseDef('conc_curl', 'Concentration Curl', 'Bicipiti', 'dumbbell'),
  ExerciseDef('incline_curl', 'Incline Dumbbell Curl', 'Bicipiti', 'dumbbell'),
  ExerciseDef('cable_curl', 'Cable Curl', 'Bicipiti', 'cable'),
  ExerciseDef('cable_hammer', 'Cable Hammer Curl', 'Bicipiti', 'cable'),
  ExerciseDef('preacher_curl', 'Preacher Curl', 'Bicipiti', 'machine'),
  ExerciseDef('machine_curl', 'Machine Curl', 'Bicipiti', 'machine'),

  // ═══════════════════════════════════════
  // BRACCIA - TRICIPITI
  // ═══════════════════════════════════════
  ExerciseDef('skullcrusher', 'Skull Crusher (EZ-Bar)', 'Tricipiti', 'barbell'),
  ExerciseDef(
      'close_grip_bp', 'Close-Grip Bench Press', 'Tricipiti', 'barbell'),
  ExerciseDef(
      'db_tri_ext', 'Dumbbell Tricep Extension', 'Tricipiti', 'dumbbell'),
  ExerciseDef('db_kickback', 'Tricep Kickback', 'Tricipiti', 'dumbbell'),
  ExerciseDef(
      'cable_pushdown', 'Cable Pushdown (Presa Dritta)', 'Tricipiti', 'cable'),
  ExerciseDef('cable_pd_rope', 'Cable Pushdown (Corda)', 'Tricipiti', 'cable'),
  ExerciseDef('cable_oh_ext', 'Cable Overhead Extension', 'Tricipiti', 'cable'),
  ExerciseDef('dips_tri', 'Tricep Dips', 'Tricipiti', 'bodyweight'),
  ExerciseDef('diamond_pu', 'Diamond Push-Up', 'Tricipiti', 'bodyweight'),
  ExerciseDef(
      'machine_tri', 'Tricep Machine Extension', 'Tricipiti', 'machine'),

  // ═══════════════════════════════════════
  // GAMBE - LEGS
  // ═══════════════════════════════════════
  ExerciseDef('front_squat', 'Front Squat', 'Quadricipiti', 'barbell'),
  ExerciseDef('box_squat', 'Box Squat', 'Quadricipiti', 'barbell'),
  ExerciseDef('hack_squat', 'Hack Squat', 'Quadricipiti', 'machine'),
  ExerciseDef('leg_press', 'Leg Press', 'Quadricipiti', 'machine'),
  ExerciseDef('leg_ext', 'Leg Extension', 'Quadricipiti', 'machine'),
  ExerciseDef('leg_curl', 'Leg Curl (Lying)', 'Femorali', 'machine'),
  ExerciseDef('seat_leg_curl', 'Leg Curl (Seated)', 'Femorali', 'machine'),
  ExerciseDef('rdl', 'Romanian Deadlift (RDL)', 'Femorali', 'barbell'),
  ExerciseDef('single_rdl', 'Single-Leg RDL', 'Femorali', 'dumbbell'),
  ExerciseDef('stiff_dl', 'Stiff-Leg Deadlift', 'Femorali', 'barbell'),
  ExerciseDef('hip_thrust', 'Hip Thrust', 'Glutei', 'barbell'),
  ExerciseDef('db_hip_thrust', 'Dumbbell Hip Thrust', 'Glutei', 'dumbbell'),
  ExerciseDef('glute_bridge', 'Glute Bridge', 'Glutei', 'bodyweight'),
  ExerciseDef('cable_kickback', 'Cable Glute Kickback', 'Glutei', 'cable'),
  ExerciseDef(
      'glute_machine', 'Glute Machine / Donkey Kick', 'Glutei', 'machine'),
  ExerciseDef('lunge', 'Lunge (Affondo)', 'Gambe', 'bodyweight'),
  ExerciseDef('walking_lunge', 'Walking Lunge', 'Gambe', 'bodyweight'),
  ExerciseDef('db_lunge', 'Dumbbell Lunge', 'Gambe', 'dumbbell'),
  ExerciseDef('reverse_lunge', 'Reverse Lunge', 'Gambe', 'bodyweight'),
  ExerciseDef('bulgarian_sq', 'Bulgarian Split Squat', 'Gambe', 'dumbbell'),
  ExerciseDef('goblet_sq', 'Goblet Squat', 'Gambe', 'kettlebell'),
  ExerciseDef('step_up', 'Step-Up', 'Gambe', 'dumbbell'),
  ExerciseDef(
      'lateral_sq', 'Lateral Squat / Skater Squat', 'Gambe', 'bodyweight'),
  ExerciseDef('calf_raise', 'Calf Raise (Piedi)', 'Polpacci', 'machine'),
  ExerciseDef('seat_calf', 'Seated Calf Raise', 'Polpacci', 'machine'),
  ExerciseDef('leg_adductor', 'Adductor Machine', 'Adduttori', 'machine'),
  ExerciseDef('leg_abductor', 'Abductor Machine', 'Abduttori', 'machine'),

  // ═══════════════════════════════════════
  // CORE - ADDOME
  // ═══════════════════════════════════════
  ExerciseDef('plank', 'Plank', 'Core', 'bodyweight', activityCategory: 'core'),
  ExerciseDef('side_plank', 'Side Plank', 'Core / Obliqui', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('hollow_hold', 'Hollow Body Hold', 'Core', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('crunch', 'Crunch', 'Addominali', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('sit_up', 'Sit-Up', 'Addominali', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('leg_raise', 'Leg Raise', 'Addominali', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('hanging_lr', 'Hanging Leg Raise', 'Addominali', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('toes_to_bar', 'Toes to Bar', 'Addominali', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('ab_wheel', 'Ab Wheel Rollout', 'Core', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('russian_twist', 'Russian Twist', 'Obliqui', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('bicycle_crunch', 'Bicycle Crunch', 'Obliqui', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('cable_crunch', 'Cable Crunch', 'Addominali', 'cable',
      activityCategory: 'core'),
  ExerciseDef('woodchopper', 'Cable Woodchopper', 'Obliqui', 'cable',
      activityCategory: 'core'),
  ExerciseDef('ab_machine', 'Crunch Machine', 'Addominali', 'machine',
      activityCategory: 'core'),
  ExerciseDef('dead_bug', 'Dead Bug', 'Core', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('bird_dog', 'Bird Dog', 'Core / Lombari', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef(
      'landmine_twist', 'Landmine Rotational Press', 'Obliqui', 'barbell',
      activityCategory: 'core'),
  ExerciseDef('pallof_press', 'Pallof Press', 'Core / Obliqui', 'cable',
      activityCategory: 'core'),
  ExerciseDef('weighted_plank', 'Weighted Plank', 'Core', 'barbell',
      activityCategory: 'core'),
  ExerciseDef('db_side_bend', 'Dumbbell Side Bend', 'Obliqui', 'dumbbell',
      activityCategory: 'core'),
  ExerciseDef('suitcase_carry', 'Suitcase Carry', 'Core / Obliqui', 'dumbbell',
      activityCategory: 'core'),
  ExerciseDef(
      'kb_front_rack_carry', 'KB Front Rack Carry', 'Core', 'kettlebell',
      activityCategory: 'core'),
  ExerciseDef('weighted_dead_bug', 'Weighted Dead Bug', 'Core', 'dumbbell',
      activityCategory: 'core'),
  ExerciseDef('stir_pot', 'Stir the Pot', 'Core', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef('bear_hold', 'Bear Hold', 'Core', 'bodyweight',
      activityCategory: 'core'),
  ExerciseDef(
      'copenhagen_plank', 'Copenhagen Plank', 'Core / Adduttori', 'bodyweight',
      activityCategory: 'core'),

  // ═══════════════════════════════════════
  // PESISTICA OLIMPICA
  // ═══════════════════════════════════════
  ExerciseDef('clean_jerk', 'Clean & Jerk', 'Corpo Intero', 'barbell'),
  ExerciseDef('snatch', 'Snatch', 'Corpo Intero', 'barbell'),
  ExerciseDef('power_clean', 'Power Clean', 'Corpo Intero', 'barbell'),
  ExerciseDef('power_snatch', 'Power Snatch', 'Corpo Intero', 'barbell'),
  ExerciseDef('hang_clean', 'Hang Clean', 'Corpo Intero', 'barbell'),
  ExerciseDef('hang_snatch', 'Hang Snatch', 'Corpo Intero', 'barbell'),
  ExerciseDef('clean_pull', 'Clean Pull', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('snatch_pull', 'Snatch Pull', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('jerk_behind', 'Jerk Behind Neck', 'Spalle', 'barbell'),
  ExerciseDef('push_jerk', 'Push Jerk', 'Spalle / Gambe', 'barbell'),
  ExerciseDef('split_jerk', 'Split Jerk', 'Corpo Intero', 'barbell'),
  ExerciseDef(
      'clean_grip_dl', 'Clean-Grip Deadlift', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('overhead_sq', 'Overhead Squat', 'Corpo Intero', 'barbell'),

  // ═══════════════════════════════════════
  // POWERLIFTING
  // ═══════════════════════════════════════
  ExerciseDef('comp_squat', 'Competition Squat (Low Bar)', 'Gambe', 'barbell'),
  ExerciseDef('comp_bench', 'Competition Bench Press', 'Petto', 'barbell'),
  ExerciseDef(
      'comp_deadlift', 'Competition Deadlift', 'Schiena / Gambe', 'barbell'),
  ExerciseDef('pause_squat', 'Pause Squat', 'Gambe', 'barbell'),
  ExerciseDef('pause_bench', 'Pause Bench Press', 'Petto', 'barbell'),
  ExerciseDef('floor_press', 'Floor Press', 'Petto / Tricipiti', 'barbell'),
  ExerciseDef('board_press', 'Board Press', 'Petto', 'barbell'),
  ExerciseDef('slingshot_bench', 'Slingshot Bench', 'Petto', 'barbell'),
  ExerciseDef('box_deadlift', 'Deadlift da Box / Deficit', 'Schiena / Gambe',
      'barbell'),
  ExerciseDef('rack_pull', 'Rack Pull', 'Schiena', 'barbell'),
  ExerciseDef('zercher_squat', 'Zercher Squat', 'Gambe / Core', 'barbell'),

  // ═══════════════════════════════════════
  // KETTLEBELL
  // ═══════════════════════════════════════
  ExerciseDef('kb_swing', 'Kettlebell Swing', 'Corpo Intero', 'kettlebell'),
  ExerciseDef('kb_snatch', 'Kettlebell Snatch', 'Corpo Intero', 'kettlebell'),
  ExerciseDef('kb_clean', 'Kettlebell Clean', 'Corpo Intero', 'kettlebell'),
  ExerciseDef('kb_press', 'Kettlebell Press', 'Spalle', 'kettlebell'),
  ExerciseDef(
      'kb_windmill', 'Kettlebell Windmill', 'Core / Spalle', 'kettlebell'),
  ExerciseDef('kb_turkish', 'Turkish Get-Up', 'Corpo Intero', 'kettlebell'),
  ExerciseDef(
      'kb_deadlift', 'Kettlebell Deadlift', 'Schiena / Gambe', 'kettlebell'),
  ExerciseDef('kb_row', 'Kettlebell Row', 'Dorsali', 'kettlebell'),
  ExerciseDef('kb_goblet', 'Kettlebell Goblet Squat', 'Gambe', 'kettlebell'),
  ExerciseDef('kb_halos', 'Kettlebell Halos', 'Spalle / Core', 'kettlebell'),

  // ═══════════════════════════════════════
  // PLIOMETRIA
  // ═══════════════════════════════════════
  // Bassa intensita e reattivita di caviglia
  ExerciseDef(
      'plyo_pogo_jump', 'Pogo Jump', 'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_pogo', 'Single-Leg Pogo Jump',
      'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_alternating_pogo', 'Alternating Pogo Jump',
      'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_line_hop_forward_back', 'Line Hop Avanti-Indietro',
      'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_line_hop_lateral', 'Line Hop Laterale',
      'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_ankle_hop', 'Ankle Hop', 'Caviglie / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_power_skip_height', 'Power Skip in Altezza',
      'Gambe / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_power_skip_distance', 'Power Skip in Avanzamento',
      'Gambe / Polpacci', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Salti verticali bilaterali
  ExerciseDef('box_jump', 'Box Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('jump_squat', 'Jump Squat', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_vertical_jump', 'Vertical Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_countermovement_jump', 'Countermovement Jump (CMJ)',
      'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_squat_jump_pause', 'Squat Jump con Pausa',
      'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_tuck_jump', 'Tuck Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_star_jump', 'Star Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_approach_jump', 'Approach Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_kneeling_jump', 'Kneeling Jump', 'Anche / Gambe', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_seated_box_jump', 'Seated Box Jump', 'Gambe / Potenza',
      'bodyweight',
      activityCategory: 'plyometrics'),

  // Salti orizzontali e balzi
  ExerciseDef('broad_jump', 'Broad Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_broad_jump_stick', 'Broad Jump con Atterraggio',
      'Gambe / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_repeated_broad_jump', 'Repeated Broad Jump',
      'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_triple_jump', 'Triple Jump', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_alternate_leg_bound', 'Alternate-Leg Bound',
      'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_bound', 'Single-Leg Bound',
      'Gamba singola / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_stair_bound', 'Stair Bound', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_bound_to_sprint', 'Bounds to Sprint',
      'Gambe / Accelerazione', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Salti laterali, rotazionali e multidirezionali
  ExerciseDef(
      'plyo_lateral_bound', 'Lateral Bound', 'Gambe / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_skater_jump', 'Skater Jump', 'Gambe / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_diagonal_bound', 'Diagonal Bound', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_crossover_bound', 'Crossover Bound',
      'Gambe / Coordinazione', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_90_degree_jump', '90-Degree Jump', 'Gambe / Rotazione',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_180_degree_jump', '180-Degree Jump', 'Gambe / Rotazione',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_rotational_jump', 'Rotational Jump',
      'Gambe / Core / Rotazione', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_lateral_box_jump', 'Lateral Box Jump',
      'Gambe / Potenza laterale', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Salti monopodalici
  ExerciseDef('lunge_jump', 'Jumping Lunge', 'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_split_squat_jump', 'Split Squat Jump', 'Gambe / Potenza',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_scissor_jump', 'Scissor Jump', 'Gambe / Coordinazione',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_vertical_jump', 'Single-Leg Vertical Jump',
      'Gamba singola / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_box_jump', 'Single-Leg Box Jump',
      'Gamba singola / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_hop_distance', 'Single-Leg Hop for Distance',
      'Gamba singola / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_triple_hop', 'Single-Leg Triple Hop',
      'Gamba singola / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_single_leg_hop_stick', 'Single-Leg Hop and Stick',
      'Gamba singola / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_lateral_single_leg_hop', 'Lateral Single-Leg Hop',
      'Gamba singola / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_medial_single_leg_hop', 'Medial Single-Leg Hop',
      'Gamba singola / Stabilita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_reactive_single_leg_hop', 'Reactive Single-Leg Hop',
      'Gamba singola / Reattivita', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Box, ostacoli e salti reattivi
  ExerciseDef('plyo_low_hurdle_hop', 'Low Hurdle Hop', 'Caviglie / Reattivita',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_hurdle_hop', 'Hurdle Hop', 'Gambe / Reattivita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_continuous_hurdle_hop', 'Continuous Hurdle Hop',
      'Gambe / Reattivita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_drop_jump', 'Drop Jump', 'Gambe / Reattivita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_depth_jump', 'Depth Jump', 'Gambe / Potenza reattiva', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_depth_jump_to_box', 'Depth Jump to Box',
      'Gambe / Potenza reattiva', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_depth_jump_to_broad', 'Depth Jump to Broad Jump',
      'Gambe / Potenza reattiva', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_drop_jump_rebound', 'Drop Jump con Rimbalzo',
      'Gambe / Reattivita', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_repeated_box_jump', 'Repeated Box Jump', 'Gambe / Potenza',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_box_jump_step_down', 'Box Jump con Discesa Controllata',
      'Gambe / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Parte superiore e palla medica
  ExerciseDef(
      'plyo_pushup', 'Plyometric Push-Up', 'Petto / Tricipiti', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_clap_pushup', 'Clap Push-Up', 'Petto / Tricipiti', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_depth_pushup', 'Depth Push-Up', 'Petto / Tricipiti', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_alternating_pushup', 'Alternating Plyometric Push-Up',
      'Petto / Tricipiti', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_med_ball_chest_pass', 'Medicine Ball Chest Pass',
      'Petto / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_med_ball_overhead_throw', 'Medicine Ball Overhead Throw',
      'Corpo intero / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_med_ball_backward_throw', 'Medicine Ball Backward Throw',
      'Corpo intero / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_med_ball_rotational_throw',
      'Medicine Ball Rotational Throw',
      'Core / Potenza rotazionale',
      'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_med_ball_scoop_toss', 'Medicine Ball Scoop Toss',
      'Anche / Core / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_med_ball_kneeling_chest_pass',
      'Kneeling Medicine Ball Chest Pass', 'Petto / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),

  // Varianti con sovraccarico o resistenza
  ExerciseDef('plyo_dumbbell_jump_squat', 'Dumbbell Jump Squat',
      'Gambe / Potenza', 'dumbbell',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_kettlebell_jump_squat', 'Kettlebell Jump Squat',
      'Gambe / Potenza', 'kettlebell',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'plyo_trap_bar_jump', 'Trap Bar Jump', 'Gambe / Potenza', 'barbell',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_band_assisted_jump', 'Band-Assisted Jump',
      'Gambe / Velocita', 'band',
      activityCategory: 'plyometrics'),
  ExerciseDef('plyo_band_resisted_broad_jump', 'Band-Resisted Broad Jump',
      'Gambe / Potenza', 'band',
      activityCategory: 'plyometrics'),

  // VELOCITA E AGILITA — tecnica di corsa, accelerazione e velocita massima
  ExerciseDef.speed(
      'speed_wall_march', 'Wall Drill March', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 45,
      aliases: ['marcia al muro', 'wall drill']),
  ExerciseDef.speed('speed_wall_switch', 'Wall Drill Switch',
      'Tecnica di corsa', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 45,
      aliases: ['cambio al muro', 'wall switch']),
  ExerciseDef.speed(
      'speed_ankling', 'Ankling', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 45,
      aliases: ['corsa di caviglia', 'sprint abc']),
  ExerciseDef.speed(
      'speed_a_march', 'A-March', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 45,
      aliases: ['marcia a', 'sprint abc']),
  ExerciseDef.speed('speed_a_skip', 'A-Skip', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 45,
      aliases: ['skip a', 'sprint abc']),
  ExerciseDef.speed('speed_b_skip', 'B-Skip', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 45,
      aliases: ['skip b', 'sprint abc']),
  ExerciseDef.speed(
      'speed_dribble_run', 'Dribble Run', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 60,
      aliases: ['dribble basso', 'corsa rapida']),
  ExerciseDef.speed('speed_straight_leg_run', 'Straight-Leg Run',
      'Tecnica di corsa', 'bodyweight',
      defaultTrials: 2,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 60,
      aliases: ['corsa gambe tese']),
  ExerciseDef.speed(
      'speed_fast_leg', 'Fast Leg Drill', 'Tecnica di corsa', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 60,
      aliases: ['gamba rapida']),
  ExerciseDef.speed('speed_falling_start', 'Falling Start Sprint',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 120,
      aliases: ['partenza in caduta']),
  ExerciseDef.speed('speed_two_point_start', 'Sprint da partenza a 2 appoggi',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 120,
      aliases: ['2 point start', 'partenza in piedi']),
  ExerciseDef.speed('speed_three_point_start', 'Sprint da partenza a 3 appoggi',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 150,
      aliases: ['3 point start']),
  ExerciseDef.speed('speed_block_start', 'Sprint dai blocchi', 'Accelerazione',
      'starting_blocks',
      defaultDistanceMeters: 30,
      defaultRestSeconds: 180,
      aliases: ['block start', 'partenza dai blocchi']),
  ExerciseDef.speed('speed_pushup_start', 'Sprint da posizione push-up',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['push up start']),
  ExerciseDef.speed('speed_prone_start', 'Sprint da posizione prona',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['prone start', 'partenza a terra']),
  ExerciseDef.speed('speed_half_kneeling_start',
      'Sprint da mezzo inginocchiato', 'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['half kneeling start']),
  ExerciseDef.speed('speed_rolling_start', 'Sprint con partenza lanciata',
      'Accelerazione', 'bodyweight',
      defaultDistanceMeters: 30,
      defaultRestSeconds: 150,
      aliases: ['rolling start']),
  ExerciseDef.speed('speed_hill_sprint', 'Sprint in salita',
      'Accelerazione resistita', 'bodyweight',
      defaultTrials: 5,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 150,
      aliases: ['hill sprint', 'scatto in salita']),
  ExerciseDef.speed('speed_sled_sprint', 'Sprint con slitta',
      'Accelerazione resistita', 'sled',
      defaultTrials: 5,
      defaultDistanceMeters: 20,
      defaultRestSeconds: 150,
      aliases: ['sled sprint', 'slitta trainata']),
  ExerciseDef.speed('speed_band_resisted_sprint',
      'Sprint con elastico resistito', 'Accelerazione resistita', 'band',
      defaultTrials: 5,
      defaultDistanceMeters: 15,
      defaultRestSeconds: 120,
      aliases: ['band resisted sprint']),
  ExerciseDef.speed('speed_partner_resisted_sprint',
      'Sprint resistito dal partner', 'Accelerazione resistita', 'partner',
      defaultTrials: 5,
      defaultDistanceMeters: 15,
      defaultRestSeconds: 120,
      aliases: ['partner resisted sprint']),
  ExerciseDef.speed(
      'speed_flying_10', 'Flying Sprint 10 m', 'Velocita massima', 'cones',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 180,
      aliases: ['flying 10', 'lanciato 10']),
  ExerciseDef.speed(
      'speed_flying_20', 'Flying Sprint 20 m', 'Velocita massima', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 240,
      aliases: ['flying 20', 'lanciato 20']),
  ExerciseDef.speed(
      'speed_flying_30', 'Flying Sprint 30 m', 'Velocita massima', 'cones',
      defaultTrials: 3,
      defaultDistanceMeters: 30,
      defaultRestSeconds: 300,
      aliases: ['flying 30', 'lanciato 30']),
  ExerciseDef.speed(
      'speed_wicket_run', 'Wicket Run', 'Velocita massima', 'mini_hurdles',
      defaultDistanceMeters: 30,
      defaultRestSeconds: 180,
      aliases: ['wickets', 'ostacolini ritmici']),
  ExerciseDef.speed(
      'speed_ins_and_outs', 'Ins and Outs', 'Velocita massima', 'cones',
      defaultDistanceMeters: 60,
      defaultRestSeconds: 240,
      aliases: ['sprint alternato veloce rilassato']),
  ExerciseDef.speed(
      'speed_build_up_40', 'Build-Up Sprint 40 m', 'Velocita massima', 'cones',
      defaultDistanceMeters: 40,
      defaultRestSeconds: 180,
      aliases: ['progressivo 40']),
  ExerciseDef.speed(
      'speed_sprint_60', 'Sprint 60 m', 'Speed endurance', 'bodyweight',
      defaultDistanceMeters: 60,
      defaultRestSeconds: 300,
      aliases: ['scatto 60']),
  ExerciseDef.speed(
      'speed_sprint_80', 'Sprint 80 m', 'Speed endurance', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 80,
      defaultRestSeconds: 360,
      aliases: ['scatto 80']),
  ExerciseDef.speed(
      'speed_sprint_120', 'Sprint 120 m', 'Speed endurance', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 120,
      defaultRestSeconds: 480,
      aliases: ['scatto 120']),
  ExerciseDef.speed(
      'speed_sprint_150', 'Sprint 150 m', 'Speed endurance', 'bodyweight',
      defaultTrials: 3,
      defaultDistanceMeters: 150,
      defaultRestSeconds: 480,
      aliases: ['scatto 150']),
  ExerciseDef.speed('speed_repeated_sprint_30', 'Repeated Sprint 30 m',
      'Speed endurance', 'cones',
      defaultTrials: 6,
      defaultDistanceMeters: 30,
      defaultRestSeconds: 30,
      aliases: ['rsa 30', 'sprint ripetuti']),

  // Decelerazione, cambi di direzione e movimento multidirezionale
  ExerciseDef.speed(
      'speed_sprint_to_stick', 'Sprint to Stick', 'Decelerazione', 'cones',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['sprint e arresto', 'stop controllato']),
  ExerciseDef.speed('speed_deceleration_zone', 'Decelerazione in zona',
      'Decelerazione', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 90,
      aliases: ['deceleration zone', 'zona di frenata']),
  ExerciseDef.speed('speed_run_cut_45', 'Run and Cut 45 gradi',
      'Cambio di direzione', 'cones',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 90,
      aliases: ['taglio 45', 'cut 45']),
  ExerciseDef.speed('speed_run_cut_90', 'Run and Cut 90 gradi',
      'Cambio di direzione', 'cones',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 120,
      aliases: ['taglio 90', 'cut 90']),
  ExerciseDef.speed('speed_run_cut_180', 'Cambio di direzione 180 gradi',
      'Cambio di direzione', 'cones',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 120,
      aliases: ['taglio 180', 'inversione']),
  ExerciseDef.speed(
      'speed_5_10_5', 'Pro Agility 5-10-5', 'Cambio di direzione', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 150,
      aliases: ['5 10 5', 'pro agility', 'shuttle laterale']),
  ExerciseDef.speed(
      'speed_505', '505 Agility Test / Drill', 'Cambio di direzione', 'cones',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 150,
      aliases: ['5-0-5', '505 test']),
  ExerciseDef.speed('speed_t_drill', 'T-Drill', 'Cambio di direzione', 'cones',
      defaultTrials: 3,
      defaultDistanceMeters: 36.6,
      defaultRestSeconds: 180,
      aliases: ['test a t', 't test']),
  ExerciseDef.speed(
      'speed_l_drill', 'L-Drill / 3 Cone Drill', 'Cambio di direzione', 'cones',
      defaultTrials: 3,
      defaultDistanceMeters: 27.4,
      defaultRestSeconds: 180,
      aliases: ['3 cone drill', 'test a l']),
  ExerciseDef.speed('speed_illinois_drill', 'Illinois Agility Drill',
      'Cambio di direzione', 'cones',
      defaultTrials: 3,
      defaultDistanceMeters: 60,
      defaultRestSeconds: 180,
      aliases: ['illinois test']),
  ExerciseDef.speed('speed_four_cone_box', 'Four Cone Box Drill',
      'Cambio di direzione', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 120,
      aliases: ['box drill', 'quadrato quattro coni']),
  ExerciseDef.speed(
      'speed_zig_zag_cones', 'Zig-Zag tra coni', 'Cambio di direzione', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 90,
      aliases: ['slalom coni', 'zig zag']),
  ExerciseDef.speed('speed_lateral_shuffle', 'Lateral Shuffle',
      'Movimento multidirezionale', 'cones',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['scivolamenti laterali']),
  ExerciseDef.speed('speed_crossover_run', 'Crossover Run',
      'Movimento multidirezionale', 'cones',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 60,
      aliases: ['corsa incrociata']),
  ExerciseDef.speed(
      'speed_backpedal', 'Backpedal', 'Movimento multidirezionale', 'cones',
      defaultDistanceMeters: 15,
      defaultRestSeconds: 60,
      aliases: ['corsa indietro']),
  ExerciseDef.speed('speed_backpedal_to_sprint', 'Backpedal to Sprint',
      'Movimento multidirezionale', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 90,
      aliases: ['indietro e sprint']),
  ExerciseDef.speed('speed_carioca', 'Carioca / Grapevine',
      'Movimento multidirezionale', 'cones',
      defaultTrials: 3,
      defaultDistanceMeters: 15,
      defaultRestSeconds: 60,
      aliases: ['grapevine', 'incroci laterali']),

  // Agilita reattiva
  ExerciseDef.speed(
      'speed_mirror_drill', 'Mirror Drill', 'Agilita reattiva', 'partner',
      defaultTrials: 5,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['esercizio specchio']),
  ExerciseDef.speed('speed_coach_point_reaction',
      'Sprint su indicazione del coach', 'Agilita reattiva', 'cones',
      defaultTrials: 6,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['coach point', 'comando direzione']),
  ExerciseDef.speed('speed_color_call', 'Reazione al colore',
      'Agilita reattiva', 'colored_cones',
      defaultTrials: 6,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['color call', 'coni colorati']),
  ExerciseDef.speed('speed_audio_cue', 'Cambio direzione su segnale sonoro',
      'Agilita reattiva', 'cones',
      defaultTrials: 6,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['auditory cue', 'segnale vocale']),
  ExerciseDef.speed('speed_ball_drop_reaction', 'Ball Drop Reaction Sprint',
      'Agilita reattiva', 'ball',
      defaultTrials: 6,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 60,
      aliases: ['presa palla in caduta']),
  ExerciseDef.speed('speed_partner_chase', 'Partner Chase Sprint',
      'Agilita reattiva', 'partner',
      defaultTrials: 5,
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['inseguimento partner']),
  ExerciseDef.speed(
      'speed_reactive_5_10_5', '5-10-5 reattivo', 'Agilita reattiva', 'cones',
      defaultDistanceMeters: 20,
      defaultRestSeconds: 150,
      aliases: ['reactive pro agility']),
  ExerciseDef.speed(
      'speed_reactive_y_drill', 'Reactive Y Drill', 'Agilita reattiva', 'cones',
      defaultTrials: 5,
      defaultDistanceMeters: 15,
      defaultRestSeconds: 90,
      aliases: ['y drill reattivo']),
  ExerciseDef.speed(
      'speed_partner_tag', 'Partner Tag Drill', 'Agilita reattiva', 'partner',
      defaultTrials: 5,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 60,
      aliases: ['acchiapparella', 'tag game']),

  // Rapidita di piedi e scaletta
  ExerciseDef.speed('speed_ladder_one_in', 'Scaletta: un appoggio per spazio',
      'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['ladder one in']),
  ExerciseDef.speed('speed_ladder_two_in', 'Scaletta: due appoggi per spazio',
      'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['ladder two in']),
  ExerciseDef.speed('speed_ladder_icky_shuffle', 'Scaletta: Icky Shuffle',
      'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['icky shuffle']),
  ExerciseDef.speed('speed_ladder_in_out', 'Scaletta: In-Out',
      'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['ladder in out']),
  ExerciseDef.speed('speed_ladder_lateral_two_in',
      'Scaletta: due appoggi laterali', 'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['lateral two in']),
  ExerciseDef.speed('speed_ladder_hopscotch', 'Scaletta: Hopscotch',
      'Rapidita di piedi', 'agility_ladder',
      defaultTrials: 3,
      defaultDistanceMeters: 8,
      defaultRestSeconds: 45,
      aliases: ['campana scaletta']),
  ExerciseDef.speed('speed_line_traveling_scissors',
      'Traveling Scissors sulla linea', 'Rapidita di piedi', 'line',
      defaultTrials: 3,
      defaultDistanceMeters: 10,
      defaultRestSeconds: 45,
      aliases: ['forbici laterali']),
  ExerciseDef.speed('speed_quick_feet_line', 'Quick Feet sulla linea',
      'Rapidita di piedi', 'line',
      defaultDistanceMeters: 10,
      defaultRestSeconds: 45,
      aliases: ['piedi rapidi linea']),

  // ═══════════════════════════════════════
  // CORPO LIBERO - FULL BODY
  // ═══════════════════════════════════════
  ExerciseDef('burpee', 'Burpee', 'Corpo Intero', 'bodyweight'),
  ExerciseDef(
      'mountain_cl', 'Mountain Climbers', 'Core / Cardio', 'bodyweight'),
  ExerciseDef('jumping_jack', 'Jumping Jacks', 'Cardio', 'bodyweight'),
  ExerciseDef(
    'sprint',
    'Sprint (Accelerazioni)',
    'Accelerazione',
    'bodyweight',
    activityCategory: 'speed_agility',
    speedGroup: 'Accelerazione',
    defaultTrials: 4,
    defaultDistanceMeters: 20,
    defaultRestSeconds: 120,
    aliases: ['scatti', 'accelerazioni'],
  ),

  // ═══════════════════════════════════════
  // PREPARAZIONE ATLETICA
  // ═══════════════════════════════════════
  ExerciseDef(
      'med_ball_throw', 'Medicine Ball Throw', 'Corpo Intero', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef(
      'med_ball_slam', 'Medicine Ball Slam', 'Core / Potenza', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('sled_push', 'Sled Push', 'Corpo Intero', 'machine'),
  ExerciseDef('sled_pull', 'Sled Pull', 'Corpo Intero', 'machine'),
  ExerciseDef('farmers_carry', 'Farmer\'s Carry', 'Corpo Intero', 'dumbbell'),
  ExerciseDef('trap_bar_dl', 'Trap Bar Deadlift', 'Corpo Intero', 'barbell'),
  ExerciseDef('landmine_press', 'Landmine Press', 'Spalle / Core', 'barbell'),
  ExerciseDef('landmine_row', 'Landmine Row', 'Dorsali', 'barbell'),
  ExerciseDef('band_pull_apart', 'Band Pull-Apart', 'Deltoide Post.', 'band'),
  ExerciseDef('band_squat', 'Band Squat', 'Gambe', 'band'),
  ExerciseDef('band_deadlift', 'Band Deadlift', 'Schiena / Gambe', 'band'),
  ExerciseDef(
      'battling_ropes', 'Battling Ropes', 'Cardio / Braccia', 'bodyweight'),
  ExerciseDef(
      'box_step_down', 'Box Step-Down (Eccentric)', 'Gambe', 'bodyweight'),
  ExerciseDef('nordic_curl', 'Nordic Hamstring Curl', 'Femorali', 'bodyweight'),
  ExerciseDef('sissy_squat', 'Sissy Squat', 'Quadricipiti', 'bodyweight'),
  ExerciseDef(
      'reverse_nordic', 'Reverse Nordic Curl', 'Quadricipiti', 'bodyweight'),

  // ═══════════════════════════════════════
  // CROSSFIT / METCON
  // ═══════════════════════════════════════
  ExerciseDef('thruster', 'Thruster', 'Corpo Intero', 'barbell'),
  ExerciseDef('wall_ball', 'Wall Ball', 'Corpo Intero', 'bodyweight'),
  ExerciseDef('kettlebell_sc', 'KB Squat Clean', 'Corpo Intero', 'kettlebell'),
  ExerciseDef('double_under', 'Double-Under (Corda)', 'Cardio', 'bodyweight',
      activityCategory: 'plyometrics'),
  ExerciseDef('ring_dip', 'Ring Dip', 'Petto / Tricipiti', 'bodyweight'),
  ExerciseDef('ring_row', 'Ring Row', 'Dorsali', 'bodyweight'),
  ExerciseDef('muscle_up', 'Muscle-Up', 'Corpo Intero', 'bodyweight'),
  ExerciseDef('ghd_situp', 'GHD Sit-Up', 'Addominali', 'machine'),
  ExerciseDef('ghd_back_ext', 'GHD Back Extension', 'Lombari', 'machine'),
  ExerciseDef('rope_climb', 'Rope Climb', 'Dorsali / Braccia', 'bodyweight'),

  // ═══════════════════════════════════════
  // MOBILITÀ E STRETCHING ATTIVO
  // ═══════════════════════════════════════
  ExerciseDef(
      'hip_circle', 'Hip Circle (Mobilità Anca)', 'Mobilità', 'bodyweight'),
  ExerciseDef(
      'world_greatest', 'World\'s Greatest Stretch', 'Mobilità', 'bodyweight'),
  ExerciseDef('ankle_mob', 'Ankle Mobility Drill', 'Mobilità', 'bodyweight'),
  ExerciseDef(
      'thoracic_rot', 'Thoracic Rotation', 'Mobilità Dorsale', 'bodyweight'),
  ExerciseDef('couch_stretch', 'Couch Stretch', 'Flessore Anca', 'bodyweight'),
  ExerciseDef('pigeon_pose', 'Pigeon Pose', 'Glutei / Anca', 'bodyweight'),
  ExerciseDef('90_90_stretch', '90/90 Hip Stretch', 'Anca', 'bodyweight'),
  ExerciseDef('cat_cow', 'Cat-Cow', 'Colonna Vert.', 'bodyweight'),
  ExerciseDef('inchworm', 'Inchworm', 'Corpo Intero', 'bodyweight'),
  ExerciseDef('leg_swing', 'Leg Swing', 'Anca / Mobilità', 'bodyweight'),
  ExerciseDef('mob_hip_circle', 'Hip Circle', 'Mobilita Anca', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_world_greatest', 'World\'s Greatest Stretch', 'Mobilita',
      'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_ankle_drill', 'Ankle Mobility Drill', 'Mobilita Caviglia',
      'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef(
      'mob_thoracic_rot', 'Thoracic Rotation', 'Mobilita Dorsale', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef(
      'mob_couch_stretch', 'Couch Stretch', 'Flessore Anca', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_90_90', '90/90 Hip Stretch', 'Anca', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_band_hip', 'Banded Hip Mobilization', 'Anca', 'band',
      activityCategory: 'mobility'),
  ExerciseDef('mob_band_ankle', 'Banded Ankle Mobilization', 'Caviglia', 'band',
      activityCategory: 'mobility'),
  ExerciseDef('mob_shoulder_cars', 'Shoulder CARs', 'Spalle', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_hip_cars', 'Hip CARs', 'Anca', 'bodyweight',
      activityCategory: 'mobility'),
  ExerciseDef('mob_hamstring_floss', 'Hamstring Floss', 'Femorali', 'band',
      activityCategory: 'mobility'),
  ExerciseDef(
      'mob_adductor_rockback', 'Adductor Rockback', 'Adduttori', 'bodyweight',
      activityCategory: 'mobility'),
];
