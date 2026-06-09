class ExerciseDef {
  final String id;
  final String name;
  final String targetMuscle;
  final String
      category; // 'barbell' | 'dumbbell' | 'machine' | 'cable' | 'bodyweight' | 'kettlebell' | 'band'
  final String activityCategory; // 'strength' | 'core' | 'mobility'

  const ExerciseDef(
    this.id,
    this.name,
    this.targetMuscle,
    this.category, {
    this.activityCategory = 'strength',
  });

  String get resolvedActivityCategory {
    if (activityCategory != 'strength') return activityCategory;
    final text = '$id $name $targetMuscle'.toLowerCase();
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

const List<ExerciseDef> exerciseDatabase = [
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
  // CORPO LIBERO - FULL BODY
  // ═══════════════════════════════════════
  ExerciseDef('burpee', 'Burpee', 'Corpo Intero', 'bodyweight'),
  ExerciseDef(
      'mountain_cl', 'Mountain Climbers', 'Core / Cardio', 'bodyweight'),
  ExerciseDef('jumping_jack', 'Jumping Jacks', 'Cardio', 'bodyweight'),
  ExerciseDef('box_jump', 'Box Jump', 'Gambe / Potenza', 'bodyweight'),
  ExerciseDef('broad_jump', 'Broad Jump', 'Gambe / Potenza', 'bodyweight'),
  ExerciseDef('jump_squat', 'Jump Squat', 'Gambe / Potenza', 'bodyweight'),
  ExerciseDef('lunge_jump', 'Jumping Lunge', 'Gambe / Potenza', 'bodyweight'),
  ExerciseDef(
      'sprint', 'Sprint (Accelerazioni)', 'Gambe / Cardio', 'bodyweight'),

  // ═══════════════════════════════════════
  // PREPARAZIONE ATLETICA
  // ═══════════════════════════════════════
  ExerciseDef(
      'med_ball_throw', 'Medicine Ball Throw', 'Corpo Intero', 'bodyweight'),
  ExerciseDef(
      'med_ball_slam', 'Medicine Ball Slam', 'Core / Potenza', 'bodyweight'),
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
  ExerciseDef('double_under', 'Double-Under (Corda)', 'Cardio', 'bodyweight'),
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
