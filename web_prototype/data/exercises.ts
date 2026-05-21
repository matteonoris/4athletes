
export interface ExerciseDefinition {
    id: string;
    name: string;
    category: string;
}

export const exerciseDatabase: ExerciseDefinition[] = [
    // --- WARM-UP / ANDATURE (Athletic Prep) ---
    { id: 'wu_skip_low', name: 'Skip Basso (Low Skip)', category: 'Warm-up' },
    { id: 'wu_skip_high', name: 'Skip Alto (High Skip)', category: 'Warm-up' },
    { id: 'wu_butt_kicks', name: 'Calciata Dietro (Butt Kicks)', category: 'Warm-up' },
    { id: 'wu_carioca', name: 'Carioca / Passo Incrociato', category: 'Warm-up' },
    { id: 'wu_a_walk', name: 'A-Walk / Marcia', category: 'Warm-up' },
    { id: 'wu_b_skip', name: 'B-Skip (Estensione)', category: 'Warm-up' },
    { id: 'wu_side_shuffle', name: 'Scivolamenti Laterali', category: 'Warm-up' },
    { id: 'wu_backpedal', name: 'Corsa all\'indietro', category: 'Warm-up' },
    { id: 'wu_gate_openers', name: 'Apertura Anche (Gate Openers)', category: 'Warm-up' },
    { id: 'wu_gate_closers', name: 'Chiusura Anche', category: 'Warm-up' },
    { id: 'wu_lunges_twist', name: 'Affondi con Torsione', category: 'Warm-up' },
    { id: 'wu_inchworm', name: 'Inchworm / Bruco', category: 'Warm-up' },

    // --- SPRINTS / SCATTI (Athletic Prep) ---
    { id: 'sprint_10m', name: 'Scatto 10m', category: 'Sprints' },
    { id: 'sprint_20m', name: 'Scatto 20m', category: 'Sprints' },
    { id: 'sprint_30m', name: 'Scatto 30m', category: 'Sprints' },
    { id: 'sprint_50m', name: 'Scatto 50m', category: 'Sprints' },
    { id: 'sprint_60m', name: 'Scatto 60m', category: 'Sprints' },
    { id: 'sprint_100m', name: 'Scatto 100m', category: 'Sprints' },
    { id: 'sprint_flying_30', name: 'Flying 30m (Lanciati)', category: 'Sprints' },
    { id: 'sprint_shuttle', name: 'Navetta (Shuttle Run)', category: 'Sprints' },
    { id: 'sprint_hill', name: 'Scatti in Salita', category: 'Sprints' },
    { id: 'sprint_resisted', name: 'Scatti con Traino/Elastico', category: 'Sprints' },

    // --- PLYOMETRICS / BALZI (Athletic Prep) ---
    { id: 'plyo_pogo', name: 'Pogo Jumps (Saltelli Caviglie)', category: 'Plyometrics' },
    { id: 'plyo_squat_jump', name: 'Squat Jumps', category: 'Plyometrics' },
    { id: 'plyo_broad_jump', name: 'Balzi a Piedi Pari (Broad Jump)', category: 'Plyometrics' },
    { id: 'plyo_bounding', name: 'Balzi Alternati (Bounding)', category: 'Plyometrics' },
    { id: 'plyo_box_jump', name: 'Box Jump', category: 'Plyometrics' },
    { id: 'plyo_depth_jump', name: 'Depth Jump (Caduta)', category: 'Plyometrics' },
    { id: 'plyo_skater', name: 'Skater Jumps (Laterali)', category: 'Plyometrics' },
    { id: 'plyo_single_leg', name: 'Balzi Monopodalici', category: 'Plyometrics' },
    { id: 'plyo_tuck_jump', name: 'Tuck Jumps (Ginocchia al petto)', category: 'Plyometrics' },
    { id: 'plyo_barrier', name: 'Salti Ostacoli (Hurdle Hops)', category: 'Plyometrics' },

    // --- LEGS (Free Weight) ---
    { id: 'back_squat', name: 'Back Squat', category: 'Legs' },
    { id: 'front_squat', name: 'Front Squat', category: 'Legs' },
    { id: 'goblet_squat', name: 'Goblet Squat', category: 'Legs' },
    { id: 'bulgarian_split_squat', name: 'Bulgarian Split Squat', category: 'Legs' },
    { id: 'walking_lunges', name: 'Walking Lunges', category: 'Legs' },
    { id: 'reverse_lunges', name: 'Reverse Lunges', category: 'Legs' },
    { id: 'rdl', name: 'Romanian Deadlift', category: 'Legs' },
    { id: 'sumo_deadlift', name: 'Sumo Deadlift', category: 'Legs' },
    { id: 'hip_thrust', name: 'Barbell Hip Thrust', category: 'Legs' },

    // --- LEGS (Machines) ---
    { id: 'leg_press', name: 'Leg Press', category: 'Legs' },
    { id: 'hack_squat', name: 'Hack Squat', category: 'Legs' },
    { id: 'leg_extension', name: 'Leg Extension', category: 'Legs' },
    { id: 'lying_leg_curl', name: 'Lying Leg Curl', category: 'Legs' },
    { id: 'seated_leg_curl', name: 'Seated Leg Curl', category: 'Legs' },
    { id: 'calf_raise_standing', name: 'Standing Calf Raise', category: 'Legs' },
    { id: 'calf_raise_seated', name: 'Seated Calf Raise', category: 'Legs' },
    { id: 'hip_abductor', name: 'Hip Abductor (Out)', category: 'Legs' },
    { id: 'hip_adductor', name: 'Hip Adductor (In)', category: 'Legs' },
    { id: 'smith_squat', name: 'Smith Machine Squat', category: 'Legs' },
    { id: 'glute_kickback_machine', name: 'Glute Kickback Machine', category: 'Legs' },

    // --- BACK (Free Weight) ---
    { id: 'deadlift', name: 'Deadlift (Conventional)', category: 'Back' },
    { id: 'barbell_row', name: 'Barbell Row', category: 'Back' },
    { id: 'pull_up', name: 'Pull Up', category: 'Back' },
    { id: 'chin_up', name: 'Chin Up', category: 'Back' },
    { id: 'single_arm_row', name: 'Dumbbell Row', category: 'Back' },
    { id: 'pendlay_row', name: 'Pendlay Row', category: 'Back' },

    // --- BACK (Machines & Cables) ---
    { id: 'lat_pulldown', name: 'Lat Pulldown', category: 'Back' },
    { id: 'seated_cable_row', name: 'Seated Cable Row', category: 'Back' },
    { id: 't_bar_row_machine', name: 'T-Bar Row Machine', category: 'Back' },
    { id: 'assisted_pull_up', name: 'Assisted Pull-Up Machine', category: 'Back' },
    { id: 'lat_pulldown_close_grip', name: 'Close Grip Lat Pulldown', category: 'Back' },
    { id: 'straight_arm_pulldown', name: 'Cable Straight Arm Pulldown', category: 'Back' },
    { id: 'face_pull', name: 'Face Pull', category: 'Back' },
    { id: 'machine_row', name: 'Machine Chest Supported Row', category: 'Back' },
    { id: 'hyperextension', name: 'Hyperextension (Back Extension)', category: 'Back' },

    // --- CHEST (Free Weight) ---
    { id: 'bench_press', name: 'Bench Press', category: 'Chest' },
    { id: 'incline_bench_press', name: 'Incline Bench Press', category: 'Chest' },
    { id: 'dumbbell_press', name: 'Dumbbell Chest Press', category: 'Chest' },
    { id: 'incline_dumbbell_press', name: 'Incline Dumbbell Press', category: 'Chest' },
    { id: 'dips', name: 'Dips', category: 'Chest' },
    { id: 'push_up', name: 'Push Up', category: 'Chest' },

    // --- CHEST (Machines & Cables) ---
    { id: 'machine_chest_press', name: 'Machine Chest Press', category: 'Chest' },
    { id: 'pec_deck', name: 'Pec Deck / Machine Fly', category: 'Chest' },
    { id: 'cable_crossover', name: 'Cable Crossover', category: 'Chest' },
    { id: 'smith_bench_press', name: 'Smith Machine Bench Press', category: 'Chest' },
    { id: 'incline_machine_press', name: 'Incline Machine Press', category: 'Chest' },
    { id: 'chest_press_converging', name: 'Converging Chest Press', category: 'Chest' },

    // --- SHOULDERS (Free Weight) ---
    { id: 'overhead_press', name: 'Overhead Press (Barbell)', category: 'Shoulders' },
    { id: 'dumbbell_shoulder_press', name: 'Dumbbell Shoulder Press', category: 'Shoulders' },
    { id: 'lateral_raise', name: 'Dumbbell Lateral Raise', category: 'Shoulders' },
    { id: 'front_raise', name: 'Dumbbell Front Raise', category: 'Shoulders' },
    { id: 'rear_delt_fly', name: 'Rear Delt Dumbbell Fly', category: 'Shoulders' },
    { id: 'arnold_press', name: 'Arnold Press', category: 'Shoulders' },
    { id: 'shrugs', name: 'Dumbbell Shrugs', category: 'Shoulders' },

    // --- SHOULDERS (Machines & Cables) ---
    { id: 'machine_shoulder_press', name: 'Machine Shoulder Press', category: 'Shoulders' },
    { id: 'cable_lateral_raise', name: 'Cable Lateral Raise', category: 'Shoulders' },
    { id: 'reverse_pec_deck', name: 'Reverse Pec Deck', category: 'Shoulders' },
    { id: 'smith_overhead_press', name: 'Smith Machine Shoulder Press', category: 'Shoulders' },
    { id: 'cable_face_pull', name: 'Cable Face Pull', category: 'Shoulders' },

    // --- ARMS (Biceps & Triceps) ---
    { id: 'barbell_curl', name: 'Barbell Curl', category: 'Arms' },
    { id: 'dumbbell_curl', name: 'Dumbbell Curl', category: 'Arms' },
    { id: 'hammer_curl', name: 'Hammer Curl', category: 'Arms' },
    { id: 'ez_bar_curl', name: 'EZ Bar Curl', category: 'Arms' },
    { id: 'cable_curl', name: 'Cable Bicep Curl', category: 'Arms' },
    { id: 'preacher_curl_machine', name: 'Preacher Curl Machine', category: 'Arms' },
    { id: 'skull_crusher', name: 'Skull Crusher', category: 'Arms' },
    { id: 'tricep_pushdown', name: 'Cable Tricep Pushdown', category: 'Arms' },
    { id: 'tricep_rope_pushdown', name: 'Cable Rope Pushdown', category: 'Arms' },
    { id: 'tricep_extension_overhead', name: 'Overhead Tricep Extension', category: 'Arms' },
    { id: 'dips_machine', name: 'Tricep Dip Machine', category: 'Arms' },

    // --- ABS & CORE ---
    { id: 'plank', name: 'Plank', category: 'Core' },
    { id: 'hanging_leg_raise', name: 'Hanging Leg Raise', category: 'Core' },
    { id: 'cable_crunch', name: 'Cable Crunch', category: 'Core' },
    { id: 'ab_machine', name: 'Abdominal Crunch Machine', category: 'Core' },
    { id: 'russian_twist', name: 'Russian Twist', category: 'Core' },

    // --- OLYMPIC ---
    { id: 'clean_and_jerk', name: 'Clean & Jerk', category: 'Olympic' },
    { id: 'snatch', name: 'Snatch', category: 'Olympic' },
    { id: 'power_clean', name: 'Power Clean', category: 'Olympic' },
    { id: 'hang_clean', name: 'Hang Clean', category: 'Olympic' },

    // --- STRETCHING & MOBILITY ---
    // Lower Body
    { id: 'str_hamstring_standing', name: 'Hamstring Stretch (Standing)', category: 'Stretching' },
    { id: 'str_hamstring_seated', name: 'Hamstring Stretch (Seated)', category: 'Stretching' },
    { id: 'str_quad_standing', name: 'Quad Stretch (Standing)', category: 'Stretching' },
    { id: 'str_calf_wall', name: 'Calf Stretch (Wall)', category: 'Stretching' },
    { id: 'str_hip_flexor', name: 'Hip Flexor Stretch (Lunge)', category: 'Stretching' },
    { id: 'str_pigeon', name: 'Pigeon Pose', category: 'Stretching' },
    { id: 'str_butterfly', name: 'Butterfly Stretch', category: 'Stretching' },
    { id: 'str_figure_four', name: 'Figure Four / Glute Stretch', category: 'Stretching' },
    { id: 'str_groin', name: 'Groin Stretch', category: 'Stretching' },
    
    // Upper Body
    { id: 'str_triceps', name: 'Triceps Overhead Stretch', category: 'Stretching' },
    { id: 'str_shoulder_cross', name: 'Shoulder Cross-Body Stretch', category: 'Stretching' },
    { id: 'str_chest_doorway', name: 'Chest Doorway Stretch', category: 'Stretching' },
    { id: 'str_biceps_wall', name: 'Biceps Wall Stretch', category: 'Stretching' },
    { id: 'str_wrist', name: 'Wrist Flexor/Extensor Stretch', category: 'Stretching' },
    
    // Back & Core
    { id: 'str_child_pose', name: 'Child\'s Pose', category: 'Stretching' },
    { id: 'str_cat_cow', name: 'Cat-Cow Stretch', category: 'Stretching' },
    { id: 'str_cobra', name: 'Cobra / Upward Dog', category: 'Stretching' },
    { id: 'str_spinal_twist', name: 'Seated Spinal Twist', category: 'Stretching' },
    { id: 'str_lat_side', name: 'Standing Side Bend (Lat Stretch)', category: 'Stretching' },
    
    // Neck
    { id: 'str_neck_tilt', name: 'Neck Lateral Tilt', category: 'Stretching' },
    { id: 'str_neck_flexion', name: 'Neck Flexion/Extension', category: 'Stretching' },
];
