import 'package:flutter/material.dart';

import '../models/training_activity_models.dart';

class WorkoutCatalogSection {
  static const preparation = 'preparation';
  static const sport = 'sport';
  static const other = 'other';
}

class WorkoutEditorKind {
  static const strength = 'strength';
  static const endurance = 'endurance';
  static const universal = 'universal';
  static const circuit = 'circuit';
}

class WorkoutModeDefinition {
  final String id;
  final String name;
  final String description;
  final List<String> aliases;

  const WorkoutModeDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.aliases = const [],
  });

  bool matches(String query) => _matches(
        query,
        [id, name, description, ...aliases],
      );
}

class WorkoutProtocolDefinition {
  final String id;
  final String name;
  final String activityId;
  final String modeId;
  final String description;
  final List<String> aliases;
  final Map<String, dynamic> defaults;

  const WorkoutProtocolDefinition({
    required this.id,
    required this.name,
    required this.activityId,
    required this.modeId,
    required this.description,
    this.aliases = const [],
    this.defaults = const {},
  });

  bool matches(String query) => _matches(
        query,
        [id, name, description, ...aliases],
      );
}

class WorkoutActivityDefinition {
  final String id;
  final String name;
  final String description;
  final String section;
  final String category;
  final String editorKind;
  final IconData icon;
  final List<String> aliases;
  final List<WorkoutModeDefinition> modes;
  final List<String> suggestedExercises;

  const WorkoutActivityDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.section,
    required this.category,
    required this.editorKind,
    required this.icon,
    this.aliases = const [],
    this.modes = const [],
    this.suggestedExercises = const [],
  });

  bool matches(String query) => _matches(
        query,
        [
          id,
          name,
          description,
          category,
          section,
          if (section == WorkoutCatalogSection.preparation)
            'preparazione atletica',
          if (section == WorkoutCatalogSection.sport) 'sport',
          if (section == WorkoutCatalogSection.other) 'altre attivita',
          ...aliases,
        ],
      );
}

class WorkoutCatalog {
  static const runningModes = [
    WorkoutModeDefinition(
      id: 'free',
      name: 'Corsa libera',
      description: 'Registrazione rapida senza struttura prescritta',
      aliases: ['libera', 'easy run'],
    ),
    WorkoutModeDefinition(
      id: 'intervals',
      name: 'Intervalli / ripetute',
      description: 'Alternanza di lavoro e recupero',
      aliases: ['ripetute', 'interval training', 'intervalli'],
    ),
    WorkoutModeDefinition(
      id: 'fartlek',
      name: 'Fartlek',
      description: 'Variazioni libere di ritmo',
    ),
  ];

  static const enduranceModes = [
    WorkoutModeDefinition(
      id: 'free',
      name: 'Attivita libera',
      description: 'Registrazione generale dello sport',
      aliases: ['libero'],
    ),
    WorkoutModeDefinition(
      id: 'continuous',
      name: 'Continuo',
      description: 'Lavoro continuo per tempo o distanza',
    ),
    WorkoutModeDefinition(
      id: 'zone_2',
      name: 'Zona 2',
      description: 'Lavoro aerobico controllato',
      aliases: ['z2'],
    ),
    WorkoutModeDefinition(
      id: 'intervals',
      name: 'Intervalli',
      description: 'Alternanza di lavoro e recupero',
      aliases: ['ripetute'],
    ),
    WorkoutModeDefinition(
      id: 'test',
      name: 'Test',
      description: 'Test di prestazione',
    ),
    WorkoutModeDefinition(
      id: 'custom',
      name: 'Personalizzato',
      description: 'Struttura definita liberamente',
    ),
  ];

  static const hiitModes = [
    WorkoutModeDefinition(
      id: 'timed_circuit',
      name: 'Circuito a tempo',
      description: 'Stazioni definite dalla durata',
      aliases: ['circuito'],
    ),
    WorkoutModeDefinition(
      id: 'reps_circuit',
      name: 'Circuito a ripetizioni',
      description: 'Stazioni definite dalle ripetizioni',
      aliases: ['circuito reps'],
    ),
    WorkoutModeDefinition(
      id: 'work_rest',
      name: 'Intervalli lavoro / recupero',
      description: 'Tempi alternati di lavoro e recupero',
      aliases: ['hiit', 'interval training'],
    ),
    WorkoutModeDefinition(
      id: 'emom',
      name: 'EMOM',
      description: 'Un lavoro a ogni minuto',
    ),
    WorkoutModeDefinition(
      id: 'amrap',
      name: 'AMRAP',
      description: 'Piu round possibili nel tempo stabilito',
    ),
    WorkoutModeDefinition(
      id: 'tabata',
      name: 'Tabata',
      description: 'Intervalli brevi ad alta intensita',
    ),
    WorkoutModeDefinition(
      id: 'for_time',
      name: 'For Time',
      description: 'Completa il lavoro nel minor tempo',
    ),
    WorkoutModeDefinition(
      id: 'custom',
      name: 'Circuito personalizzato',
      description: 'Round, stazioni e recuperi liberi',
    ),
  ];

  static const protocols = [
    WorkoutProtocolDefinition(
      id: 'norwegian_4x4',
      name: 'Norwegian 4x4',
      activityId: 'running',
      modeId: 'intervals',
      description: '4 x 4 minuti intensi con 3 minuti di recupero',
      aliases: ['4x4', 'norvegese', 'norwegian 4×4'],
      defaults: {
        'workUnit': 'time',
        'repetitions': 4,
        'series': 1,
        'workSeconds': 240,
        'repRecoveryUnit': 'time',
        'repRecoverySeconds': 180,
        'repRecoveryStyle': 'active',
      },
    ),
    WorkoutProtocolDefinition(
      id: '30_30',
      name: '30 secondi / 30 secondi',
      activityId: 'running',
      modeId: 'intervals',
      description: 'Ripetute brevi con rapporto lavoro-recupero 1:1',
      aliases: ['30/30', '30"/30"'],
      defaults: {
        'workUnit': 'time',
        'series': 1,
        'workSeconds': 30,
        'repRecoveryUnit': 'time',
        'repRecoverySeconds': 30,
        'repRecoveryStyle': 'active',
      },
    ),
    WorkoutProtocolDefinition(
      id: '4x8_minutes',
      name: '4 x 8 minuti',
      activityId: 'running',
      modeId: 'intervals',
      description: 'Quattro intervalli da otto minuti',
      aliases: ['4x8', '4×8'],
      defaults: {
        'workUnit': 'time',
        'repetitions': 4,
        'series': 1,
        'workSeconds': 480,
      },
    ),
  ];

  static const activities = [
    WorkoutActivityDefinition(
      id: 'dryland_strength',
      name: 'Forza',
      description: 'Serie, ripetizioni, carico e RPE',
      section: WorkoutCatalogSection.preparation,
      category: ActivityCategory.strength,
      editorKind: WorkoutEditorKind.strength,
      icon: Icons.fitness_center,
      aliases: ['pesi', 'palestra', 'strength'],
      suggestedExercises: [
        'Back Squat',
        'Bench Press',
        'Pull-Up',
        'Bulgarian Split Squat',
      ],
    ),
    WorkoutActivityDefinition(
      id: 'dryland_plyometrics',
      name: 'Pliometria',
      description: 'Salti, balzi, altezza e contatti',
      section: WorkoutCatalogSection.preparation,
      category: ActivityCategory.plyometrics,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.bolt,
      aliases: ['salti', 'balzi', 'plyo'],
      suggestedExercises: [
        'Countermovement Jump (CMJ)',
        'Box Jump',
        'Broad Jump',
        'Drop Jump',
        'Pogo Jump',
        'Hurdle Hop',
        'Lateral Bound',
        'Medicine Ball Chest Pass',
      ],
    ),
    WorkoutActivityDefinition(
      id: 'dryland_speed_agility',
      name: 'Velocità e agilità',
      description: 'Sprint, cambi di direzione e drill',
      section: WorkoutCatalogSection.preparation,
      category: ActivityCategory.speedAgility,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.speed,
      aliases: ['sprint', 'agility', 'velocita'],
      suggestedExercises: [
        'Falling Start Sprint',
        'Flying Sprint 20 m',
        'Pro Agility 5-10-5',
        'Sprint to Stick',
        'Mirror Drill',
      ],
    ),
    WorkoutActivityDefinition(
      id: 'conditioning_hiit',
      name: 'Conditioning / HIIT',
      description: 'Circuiti, intervalli, EMOM e AMRAP',
      section: WorkoutCatalogSection.preparation,
      category: ActivityCategory.circuit,
      editorKind: WorkoutEditorKind.circuit,
      icon: Icons.loop,
      aliases: ['circuito', 'misto', 'conditioning', 'hiit'],
      modes: hiitModes,
    ),
    WorkoutActivityDefinition(
      id: 'powerlifting',
      name: 'Powerlifting',
      description: 'Squat, panca, stacco e varianti',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.strength,
      editorKind: WorkoutEditorKind.strength,
      icon: Icons.fitness_center,
      aliases: ['pesi', 'squat panca stacco'],
      suggestedExercises: [
        'Competition Squat',
        'Competition Bench Press',
        'Competition Deadlift',
      ],
    ),
    WorkoutActivityDefinition(
      id: 'weightlifting',
      name: 'Weightlifting',
      description: 'Snatch, clean, jerk e varianti',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.strength,
      editorKind: WorkoutEditorKind.strength,
      icon: Icons.fitness_center,
      aliases: ['pesi', 'sollevamento pesi', 'olympic lifting'],
      suggestedExercises: ['Snatch', 'Clean & Jerk', 'Clean Pull', 'Jerk'],
    ),
    WorkoutActivityDefinition(
      id: 'calcio',
      name: 'Calcio',
      description: 'Allenamento, partita o lavoro tecnico',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.sports_soccer,
      aliases: ['soccer', 'football'],
    ),
    WorkoutActivityDefinition(
      id: 'rowing',
      name: 'Canottaggio',
      description: 'Uscita, intervalli o lavoro al remoergometro',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.rowing,
      aliases: ['vogatore', 'rowing', 'remoergometro'],
      modes: enduranceModes,
    ),
    WorkoutActivityDefinition(
      id: 'cycling',
      name: 'Ciclismo',
      description: 'Uscita, rulli, distanza e potenza',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.directions_bike,
      aliases: ['bici', 'bike', 'ciclette'],
      modes: enduranceModes,
    ),
    WorkoutActivityDefinition(
      id: 'running',
      name: 'Corsa',
      description: 'Corsa libera, ripetute o Fartlek',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.directions_run,
      aliases: ['running', 'jogging', 'ripetute'],
      modes: runningModes,
    ),
    WorkoutActivityDefinition(
      id: 'hiking',
      name: 'Hiking',
      description: 'Trekking, camminata e dislivello',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.hiking,
      aliases: ['trekking', 'escursionismo'],
      modes: enduranceModes,
    ),
    WorkoutActivityDefinition(
      id: 'swimming',
      name: 'Nuoto',
      description: 'Vasche, stile, distanza e intervalli',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.pool,
      aliases: ['swim', 'vasche'],
      modes: enduranceModes,
    ),
    WorkoutActivityDefinition(
      id: 'alpine_skiing',
      name: 'Sci alpino',
      description: 'Sciata libera, allenamento o pali',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.downhill_skiing,
      aliases: ['sci', 'alpine skiing'],
    ),
    WorkoutActivityDefinition(
      id: 'cross_country_skiing',
      name: 'Sci di fondo',
      description: 'Tecnica classica, skating o intervalli',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.downhill_skiing,
      aliases: ['fondo', 'cross-country skiing'],
      modes: enduranceModes,
    ),
    WorkoutActivityDefinition(
      id: 'tennis',
      name: 'Tennis',
      description: 'Allenamento tecnico o partita',
      section: WorkoutCatalogSection.sport,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.sports_tennis,
    ),
    WorkoutActivityDefinition(
      id: 'mobility_recovery',
      name: 'Mobilita / Recupero',
      description: 'Mobilita, core, respirazione e recupero',
      section: WorkoutCatalogSection.other,
      category: ActivityCategory.mobility,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.self_improvement,
      aliases: ['stretching', 'core', 'recupero', 'mobilita'],
    ),
    WorkoutActivityDefinition(
      id: 'other',
      name: 'Altro',
      description: 'Attivita o sessione personalizzata',
      section: WorkoutCatalogSection.other,
      category: ActivityCategory.other,
      editorKind: WorkoutEditorKind.universal,
      icon: Icons.add_circle_outline,
      aliases: ['personalizzato'],
    ),
    WorkoutActivityDefinition(
      id: 'external_import',
      name: 'Importa da app esterne',
      description: 'Apple Health, Health Connect e provider collegati',
      section: WorkoutCatalogSection.other,
      category: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      icon: Icons.sync,
      aliases: ['apple health', 'health connect', 'garmin', 'importa'],
    ),
  ];

  static const _additionalSports = [
    ('american_football', 'Football americano', Icons.sports_football),
    ('baseball', 'Baseball', Icons.sports_baseball),
    ('basketball', 'Basket', Icons.sports_basketball),
    ('volleyball', 'Pallavolo', Icons.sports_volleyball),
    ('rugby', 'Rugby', Icons.sports_rugby),
    ('handball', 'Pallamano', Icons.sports_handball),
    ('water_polo', 'Pallanuoto', Icons.water_drop),
    ('field_hockey', 'Hockey su prato', Icons.sports_hockey),
    ('ice_hockey', 'Hockey su ghiaccio', Icons.sports_hockey),
    ('snowboarding', 'Snowboard', Icons.snowboarding),
    ('ice_skating', 'Pattinaggio su ghiaccio', Icons.ice_skating),
    ('bobsleigh', 'Bob / Slittino', Icons.sledding),
    ('curling', 'Curling', Icons.sports_cricket),
    ('walking', 'Camminata', Icons.directions_walk),
    ('road_running', 'Corsa su strada', Icons.directions_run),
    ('trail_running', 'Trail running', Icons.terrain),
    ('running_treadmill', 'Corsa su tapis roulant', Icons.directions_run),
    ('track_field', 'Corsa in pista', Icons.stadium_outlined),
    ('marathon', 'Maratona', Icons.directions_run),
    ('triathlon', 'Triathlon', Icons.pool),
    ('kayaking', 'Kayak', Icons.kayaking),
    ('surfing', 'Surf', Icons.surfing),
    ('sailing', 'Vela', Icons.sailing),
    ('boxing', 'Boxe', Icons.sports_mma),
    ('martial_arts', 'Arti marziali', Icons.sports_martial_arts),
    ('wrestling', 'Lotta', Icons.sports_mma),
    ('judo', 'Judo', Icons.sports_martial_arts),
    ('karate', 'Karate', Icons.sports_martial_arts),
    ('taekwondo', 'Taekwondo', Icons.sports_martial_arts),
    ('kickboxing', 'Kickboxing', Icons.sports_martial_arts),
    ('fencing', 'Scherma', Icons.sports_kabaddi),
    ('badminton', 'Badminton', Icons.sports_tennis),
    ('table_tennis', 'Tennis tavolo', Icons.sports_tennis),
    ('padel', 'Padel', Icons.sports_tennis),
    ('squash', 'Squash', Icons.sports_tennis),
    ('golf', 'Golf', Icons.sports_golf),
    ('gymnastics', 'Ginnastica', Icons.sports_gymnastics),
    ('equestrian', 'Equitazione', Icons.sports_score),
    ('skateboarding', 'Skateboard', Icons.skateboarding),
    ('spearfishing', 'Pesca subacquea', Icons.scuba_diving),
    ('scuba_diving', 'Immersione subacquea', Icons.scuba_diving),
    ('kite_surfing', 'Kitesurf', Icons.kitesurfing),
    ('water_skiing', 'Sci nautico', Icons.water),
    ('cricket', 'Cricket', Icons.sports_cricket),
    ('lacrosse', 'Lacrosse', Icons.sports_rugby),
    ('archery', 'Tiro con l arco', Icons.gps_fixed),
    ('bowling', 'Bowling', Icons.sports),
    ('billiards', 'Biliardo', Icons.adjust),
    ('darts', 'Freccette', Icons.gps_fixed),
    ('shooting', 'Tiro sportivo', Icons.gps_fixed),
    ('crossfit', 'CrossFit', Icons.fitness_center),
    ('yoga', 'Yoga', Icons.self_improvement),
    ('pilates', 'Pilates', Icons.self_improvement),
    ('aerobics', 'Aerobica', Icons.accessibility_new),
    ('hyperarch', 'Hyperarch Fascia Training', Icons.fitness_center),
    ('tendon_isometrics', 'Isometrie tendinee', Icons.accessibility_new),
  ];

  static List<WorkoutActivityDefinition> get allActivities => [
        ...activities,
        ..._additionalSports.map((sport) {
          final running = _isRunningFamilyId(sport.$1);
          return WorkoutActivityDefinition(
            id: sport.$1,
            name: sport.$2,
            description: running
                ? 'Corsa libera, ripetute o Fartlek'
                : 'Registra una sessione di ${sport.$2.toLowerCase()}',
            section: WorkoutCatalogSection.sport,
            category: ActivityCategory.sport,
            editorKind: running
                ? WorkoutEditorKind.endurance
                : WorkoutEditorKind.universal,
            icon: sport.$3,
            modes: running ? runningModes : const [],
          );
        }),
      ];

  static WorkoutActivityDefinition byId(String id) {
    return maybeById(id) ??
        activities.firstWhere((activity) => activity.id == 'other');
  }

  /// Returns an editor definition without changing a legacy session's sport ID.
  ///
  /// Some sessions were saved before every sport was represented in this
  /// catalog. Falling back to `other` while editing those sessions would make
  /// the next save change their sport. This definition keeps the original ID
  /// and selects the closest editor available in the unified workout flow.
  static WorkoutActivityDefinition editableDefinition(
    String sportId, {
    String? displayName,
  }) {
    final normalizedId = _normalizedId(sportId);
    final catalogActivity = maybeById(normalizedId);
    if (catalogActivity != null) return catalogActivity;

    final strength = _matchesAny(normalizedId, const [
      'forza',
      'strength',
      'weightlift',
      'powerlift',
      'bodybuild',
      'crossfit',
    ]);
    final speedAgility = _matchesAny(normalizedId, const [
      'veloc',
      'speed',
      'agilit',
      'agility',
    ]);
    final circuit = _matchesAny(normalizedId, const [
      'circuit',
      'conditioning',
      'hiit',
    ]);
    final running = _isRunningFamilyId(normalizedId);
    final endurance = running ||
        _matchesAny(normalizedId, const [
          'running',
          'corsa',
          'cycling',
          'ciclismo',
          'endurance',
          'resistenza',
        ]) ||
        const {
          'road_running',
          'track_field',
          'spinning',
          'marathon',
          'triathlon',
          'walking',
          'trail_running',
          'cross_country_skiing',
          'swimming',
          'rowing',
          'hiking',
        }.contains(normalizedId);

    final category = strength
        ? ActivityCategory.strength
        : speedAgility
            ? ActivityCategory.speedAgility
            : circuit
                ? ActivityCategory.circuit
                : endurance
                    ? ActivityCategory.endurance
                    : ActivityCategory.sport;
    final editorKind = strength
        ? WorkoutEditorKind.strength
        : circuit
            ? WorkoutEditorKind.circuit
            : endurance
                ? WorkoutEditorKind.endurance
                : WorkoutEditorKind.universal;
    final name = displayName?.trim();

    return WorkoutActivityDefinition(
      id: normalizedId.isEmpty ? 'other' : normalizedId,
      name: name == null || name.isEmpty ? displayNameForLegacy(sportId) : name,
      description: editorKind == WorkoutEditorKind.strength
          ? 'Serie, ripetizioni, carico e RPE'
          : editorKind == WorkoutEditorKind.endurance
              ? 'Durata, distanza, ritmo e intensita'
              : 'Registra e struttura la sessione',
      section: WorkoutCatalogSection.sport,
      category: category,
      editorKind: editorKind,
      icon: strength
          ? Icons.fitness_center
          : endurance
              ? Icons.directions_run
              : speedAgility
                  ? Icons.speed
                  : circuit
                      ? Icons.loop
                      : Icons.sports,
      modes: running ? runningModes : const [],
    );
  }

  static bool _isRunningFamilyId(String id) {
    final normalized = _normalizedId(id);
    return const {
          'running',
          'road_running',
          'trail_running',
          'running_treadmill',
          'track_field',
          'track_and_field',
          'marathon',
        }.contains(normalized) ||
        normalized.contains('running');
  }

  static bool _matchesAny(String value, List<String> fragments) =>
      fragments.any(value.contains);

  static String displayNameForLegacy(String sportId) => displayName(sportId);

  static WorkoutActivityDefinition? maybeById(String? id) {
    final normalizedId = _normalizedId(id);
    if (normalizedId.isEmpty) return null;
    for (final activity in allActivities) {
      if (activity.id == normalizedId) return activity;
    }
    return null;
  }

  /// Returns the user-facing label for a stable sport ID.
  ///
  /// IDs remain unchanged because filters, scoring, Health imports and workout
  /// restoration rely on them. Presentation code should use this method.
  static String displayName(String? sportId) {
    final normalizedId = _normalizedId(sportId);
    if (normalizedId.isEmpty) return 'Attività';

    final catalogActivity = maybeById(normalizedId);
    if (catalogActivity != null) return catalogActivity.name;

    const legacyNames = {
      'forza': 'Forza',
      'pliometria': 'Pliometria',
      'velocita': 'Velocità e agilità',
      'velocita_agilita': 'Velocità e agilità',
      'velocita_e_agilita': 'Velocità e agilità',
      'resistenza': 'Resistenza',
      'mobilita': 'Mobilità',
      'mobilita_core': 'Mobilità e core',
      'mobilita_recupero': 'Mobilità / Recupero',
      'strength': 'Forza',
      'plyometrics': 'Pliometria',
      'speed_agility': 'Velocità e agilità',
      'endurance': 'Resistenza',
      'mobility_core': 'Mobilità e core',
      'mixed_circuit': 'Circuito misto',
      'dryland': 'Preparazione atletica',
      'dryland_forza': 'Forza',
      'dryland_pliometria': 'Pliometria',
      'dryland_velocita': 'Velocità e agilità',
      'dryland_velocita_agilita': 'Velocità e agilità',
      'dryland_velocita_e_agilita': 'Velocità e agilità',
      'dryland_conditioning_hiit': 'Conditioning / HIIT',
      'athletic_prep': 'Preparazione atletica',
      'dryland_endurance': 'Resistenza',
      'dryland_mobility_core': 'Mobilità e core',
      'dryland_mixed_circuit': 'Circuito misto',
      'dryland_core': 'Core',
      'dryland_circuit': 'Circuito',
      'dryland_test': 'Test',
      'ski': 'Sci alpino',
      'skiing': 'Sci alpino',
    };
    final legacyName = legacyNames[normalizedId];
    if (legacyName != null) return legacyName;

    final words = normalizedId
        .split(RegExp(r'[_\-\s]+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'Attività';
    final humanized = words.join(' ');
    return humanized[0].toUpperCase() + humanized.substring(1);
  }

  /// Resolves legacy labels and category values to the canonical stored ID.
  static String stableSportId(String? value, {String fallback = 'dryland'}) {
    final normalizedId = _normalizedId(value);
    if (normalizedId.isEmpty) return fallback;

    const additionalStableIds = {
      'dryland',
      'dryland_endurance',
      'dryland_mobility_core',
      'dryland_mixed_circuit',
      'dryland_core',
      'dryland_circuit',
      'dryland_test',
    };
    if (maybeById(normalizedId) != null ||
        additionalStableIds.contains(normalizedId)) {
      return normalizedId;
    }

    const aliases = {
      'forza': 'dryland_strength',
      'strength': 'dryland_strength',
      'dryland_forza': 'dryland_strength',
      'pliometria': 'dryland_plyometrics',
      'plyometrics': 'dryland_plyometrics',
      'dryland_pliometria': 'dryland_plyometrics',
      'velocita': 'dryland_speed_agility',
      'velocita_agilita': 'dryland_speed_agility',
      'velocita_e_agilita': 'dryland_speed_agility',
      'speed_agility': 'dryland_speed_agility',
      'dryland_velocita': 'dryland_speed_agility',
      'dryland_velocita_agilita': 'dryland_speed_agility',
      'dryland_velocita_e_agilita': 'dryland_speed_agility',
      'resistenza': 'dryland_endurance',
      'endurance': 'dryland_endurance',
      'mobilita': 'dryland_mobility_core',
      'mobilita_core': 'dryland_mobility_core',
      'mobilita_recupero': 'dryland_mobility_core',
      'mobility': 'dryland_mobility_core',
      'mobility_core': 'dryland_mobility_core',
      'circuit': 'dryland_mixed_circuit',
      'circuito': 'dryland_mixed_circuit',
      'circuito_misto': 'dryland_mixed_circuit',
      'mixed_circuit': 'dryland_mixed_circuit',
      'dryland_conditioning_hiit': 'dryland_mixed_circuit',
      'preparazione': 'athletic_prep',
      'preparazione_atletica': 'athletic_prep',
      'athletic_prep': 'athletic_prep',
    };
    final alias = aliases[normalizedId];
    if (alias != null) return alias;

    return fallback;
  }

  static String _normalizedId(String? value) {
    return value
            ?.trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[àáâäãå]'), 'a')
            .replaceAll(RegExp(r'[èéêë]'), 'e')
            .replaceAll(RegExp(r'[ìíîï]'), 'i')
            .replaceAll(RegExp(r'[òóôöõ]'), 'o')
            .replaceAll(RegExp(r'[ùúûü]'), 'u')
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '') ??
        '';
  }

  static WorkoutProtocolDefinition? protocolById(String? id) {
    if (id == null) return null;
    for (final protocol in protocols) {
      if (protocol.id == id) return protocol;
    }
    return null;
  }

  static List<WorkoutProtocolDefinition> protocolsFor(
    String activityId,
    String? modeId,
  ) {
    if (modeId != 'intervals') return const [];
    const reusableEndurance = {
      'running',
      'cycling',
      'swimming',
      'rowing',
      'cross_country_skiing',
    };
    if (!reusableEndurance.contains(activityId)) return const [];
    return protocols
        .map(
          (protocol) => WorkoutProtocolDefinition(
            id: protocol.id,
            name: protocol.name,
            activityId: activityId,
            modeId: protocol.modeId,
            description: protocol.description,
            aliases: protocol.aliases,
            defaults: protocol.defaults,
          ),
        )
        .toList();
  }
}

bool _matches(String query, Iterable<String> values) {
  final normalized = _normalize(query);
  if (normalized.isEmpty) return true;
  final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
  final haystack = _normalize(values.join(' '));
  return tokens.every(haystack.contains);
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('×', 'x')
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
