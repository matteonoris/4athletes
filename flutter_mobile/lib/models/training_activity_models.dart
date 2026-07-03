import 'models.dart';

class ActivitySource {
  static const coach = 'coach';
  static const athlete = 'athlete';
  static const imported = 'imported';
}

class ActivityStatus {
  static const planned = 'planned';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

class AttendanceStatus {
  static const pending = 'pending';
  static const present = 'present';
  static const absent = 'absent';
}

class ActivityCategory {
  static const athleticPrep = 'athletic_prep';
  static const strength = 'strength';
  static const plyometrics = 'plyometrics';
  static const speedAgility = 'speed_agility';
  static const endurance = 'endurance';
  static const mobility = 'mobility';
  static const core = 'core';
  static const circuit = 'circuit';
  static const sport = 'sport';
  static const test = 'test';
  static const other = 'other';
}

class DrylandPrepType {
  static const strength = 'strength';
  static const plyometrics = 'plyometrics';
  static const speedAgility = 'speed_agility';
  static const endurance = 'endurance';
  static const mobilityCore = 'mobility_core';
  static const mixedCircuit = 'mixed_circuit';

  static const ordered = [
    strength,
    plyometrics,
    speedAgility,
    endurance,
    mobilityCore,
    mixedCircuit,
  ];
}

class TrainingBlockType {
  static const strength = ActivityCategory.strength;
  static const plyometrics = ActivityCategory.plyometrics;
  static const speedAgility = ActivityCategory.speedAgility;
  static const endurance = ActivityCategory.endurance;
  static const mobility = ActivityCategory.mobility;
  static const core = ActivityCategory.core;
  static const circuit = ActivityCategory.circuit;
  static const test = ActivityCategory.test;
  static const note = 'note';
}

class TrainingPhase {
  static const warmup = 'warmup';
  static const main = 'main';
  static const cooldown = 'cooldown';

  static const ordered = [warmup, main, cooldown];

  static String label(String phase) {
    switch (phase) {
      case warmup:
        return 'Riscaldamento';
      case cooldown:
        return 'Defaticamento';
      case main:
      default:
        return 'Lavoro principale';
    }
  }

  static String normalize(dynamic value) {
    final text = value?.toString();
    if (text == warmup || text == main || text == cooldown) return text!;
    return main;
  }
}

class UnilateralType {
  static const bilateral = 'bilateral';
  static const unilateral = 'unilateral';
  static const bothSupported = 'bothSupported';
}

class UnilateralMode {
  static const bilateral = 'bilateral';
  static const right = 'right';
  static const left = 'left';
}

class TrainingSide {
  static const right = 'right';
  static const left = 'left';
  static const both = 'both';
  static const none = 'none';
}

class TemplateOwnerType {
  static const athlete = 'athlete';
  static const coach = 'coach';
  static const team = 'team';
}

dynamic _deepCopy(dynamic value) {
  if (value is Map) {
    return value
        .map((key, child) => MapEntry(key.toString(), _deepCopy(child)));
  }
  if (value is List) return value.map(_deepCopy).toList();
  return value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

num? _num(dynamic value) {
  if (value is num) return value;
  if (value == null) return null;
  final normalized = value.toString().replaceAll(',', '.');
  return num.tryParse(normalized);
}

int? _int(dynamic value) => _num(value)?.round();

double? _double(dynamic value) => _num(value)?.toDouble();

String? _string(dynamic value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

class ExerciseDefinition {
  final String id;
  final String name;
  final List<String> equipmentOptions;
  final String? defaultEquipment;
  final List<String> variants;
  final String unilateralType;
  final String? primaryMuscleGroup;
  final bool isMainLift;
  final bool supportsOneRm;
  final String? createdBy;
  final String? createdByAthleteId;
  final bool visibleToCoach;
  final bool isCustom;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    this.equipmentOptions = const [],
    this.defaultEquipment,
    this.variants = const [],
    this.unilateralType = UnilateralType.bilateral,
    this.primaryMuscleGroup,
    this.isMainLift = false,
    this.supportsOneRm = false,
    this.createdBy,
    this.createdByAthleteId,
    this.visibleToCoach = false,
    this.isCustom = false,
  });

  factory ExerciseDefinition.fromJson(Map<String, dynamic> json) {
    return ExerciseDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      equipmentOptions: (json['equipmentOptions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      defaultEquipment: _string(json['defaultEquipment']),
      variants:
          (json['variants'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      unilateralType:
          json['unilateralType']?.toString() ?? UnilateralType.bilateral,
      primaryMuscleGroup: _string(json['primaryMuscleGroup']),
      isMainLift: json['isMainLift'] == true,
      supportsOneRm: json['supportsOneRm'] == true,
      createdBy: _string(json['createdBy']),
      createdByAthleteId: _string(json['createdByAthleteId']),
      visibleToCoach: json['visibleToCoach'] == true,
      isCustom: json['isCustom'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'equipmentOptions': equipmentOptions,
        'defaultEquipment': defaultEquipment,
        'variants': variants,
        'unilateralType': unilateralType,
        'primaryMuscleGroup': primaryMuscleGroup,
        'isMainLift': isMainLift,
        'supportsOneRm': supportsOneRm,
        'createdBy': createdBy,
        'createdByAthleteId': createdByAthleteId,
        'visibleToCoach': visibleToCoach,
        'isCustom': isCustom,
      };
}

class StrengthSet {
  final int setNumber;
  final double? kg;
  final int? reps;
  final double? percent1RM;
  final double? rpe;
  final int? rir;
  final int? restSeconds;
  final int? durationSeconds;
  final String? tempo;
  final String? notes;
  final String side;

  const StrengthSet({
    required this.setNumber,
    this.kg,
    this.reps,
    this.percent1RM,
    this.rpe,
    this.rir,
    this.restSeconds,
    this.durationSeconds,
    this.tempo,
    this.notes,
    this.side = TrainingSide.none,
  });

  factory StrengthSet.fromJson(Map<String, dynamic> json,
      {int fallbackSet = 1}) {
    return StrengthSet(
      setNumber: _int(json['setNumber'] ?? json['set']) ?? fallbackSet,
      kg: _double(json['kg']),
      reps: _int(json['reps']),
      percent1RM: _double(json['percent1RM'] ?? json['percent1rm']),
      rpe: _double(json['rpe']),
      rir: _int(json['rir']),
      restSeconds: _int(json['restSeconds']),
      durationSeconds: _int(json['durationSeconds'] ?? json['holdSeconds']),
      tempo: _string(json['tempo']),
      notes: _string(json['notes']),
      side: json['side']?.toString() ?? TrainingSide.none,
    );
  }

  bool get hasValidVolume => (kg ?? 0) > 0 && (reps ?? 0) > 0;

  double get volumeKg => hasValidVolume ? kg! * reps! : 0;

  bool get hasValidTempo {
    final value = tempo;
    if (value == null || value.isEmpty) return true;
    return RegExp(r'^\d+-\d+-\d+-\d+$').hasMatch(value);
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'kg': kg,
        'reps': reps,
        'percent1RM': percent1RM,
        'rpe': rpe,
        'rir': rir,
        'restSeconds': restSeconds,
        'durationSeconds': durationSeconds,
        'tempo': tempo,
        'notes': notes,
        'side': side,
      };
}

class ExerciseEntry {
  final String exerciseId;
  final String name;
  final String? equipment;
  final String? variant;
  final String unilateralMode;
  final List<StrengthSet> sets;
  final bool isCustom;
  final String? createdByAthleteId;

  const ExerciseEntry({
    required this.exerciseId,
    required this.name,
    this.equipment,
    this.variant,
    this.unilateralMode = UnilateralMode.bilateral,
    this.sets = const [],
    this.isCustom = false,
    this.createdByAthleteId,
  });

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    final parsedSets = rawSets is List
        ? rawSets.asMap().entries.map((entry) {
            return StrengthSet.fromJson(
              _map(entry.value),
              fallbackSet: entry.key + 1,
            );
          }).toList()
        : <StrengthSet>[];
    return ExerciseEntry(
      exerciseId: (json['exerciseId'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      equipment: _string(json['equipment']),
      variant: _string(json['variant']),
      unilateralMode:
          json['unilateralMode']?.toString() ?? UnilateralMode.bilateral,
      sets: parsedSets,
      isCustom: json['isCustom'] == true,
      createdByAthleteId: _string(json['createdByAthleteId']),
    );
  }

  double get volumeKg => sets.fold(0, (sum, set) => sum + set.volumeKg);

  int get repsTotal => sets.fold(0, (sum, set) => sum + (set.reps ?? 0));

  bool get isSingleSideRow =>
      unilateralMode == UnilateralMode.left ||
      unilateralMode == UnilateralMode.right;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'equipment': equipment,
        'variant': variant,
        'unilateralMode': unilateralMode,
        'sets': sets.map((set) => set.toJson()).toList(),
        'isCustom': isCustom,
        'createdByAthleteId': createdByAthleteId,
      };
}

class PlyometricSet {
  final int setNumber;
  final int? reps;
  final int? contacts;
  final double? heightCm;
  final double? distanceM;
  final String? direction;
  final String side;
  final int? restSeconds;
  final String? notes;

  const PlyometricSet({
    required this.setNumber,
    this.reps,
    this.contacts,
    this.heightCm,
    this.distanceM,
    this.direction,
    this.side = TrainingSide.none,
    this.restSeconds,
    this.notes,
  });

  factory PlyometricSet.fromJson(Map<String, dynamic> json,
      {int fallbackSet = 1}) {
    return PlyometricSet(
      setNumber: _int(json['setNumber']) ?? fallbackSet,
      reps: _int(json['reps']),
      contacts: _int(json['contacts']),
      heightCm: _double(json['heightCm']),
      distanceM: _double(json['distanceM']),
      direction: _string(json['direction']),
      side: json['side']?.toString() ?? TrainingSide.none,
      restSeconds: _int(json['restSeconds']),
      notes: _string(json['notes']),
    );
  }

  int get effectiveContacts => contacts ?? reps ?? 0;

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'contacts': contacts,
        'heightCm': heightCm,
        'distanceM': distanceM,
        'direction': direction,
        'side': side,
        'restSeconds': restSeconds,
        'notes': notes,
      };
}

class PlyometricEntry {
  final String exerciseName;
  final String type;
  final List<PlyometricSet> sets;
  final String? direction;
  final String unilateralMode;
  final String? notes;

  const PlyometricEntry({
    required this.exerciseName,
    required this.type,
    this.sets = const [],
    this.direction,
    this.unilateralMode = UnilateralMode.bilateral,
    this.notes,
  });

  factory PlyometricEntry.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    return PlyometricEntry(
      exerciseName: json['exerciseName']?.toString() ?? '',
      type: json['type']?.toString() ?? 'custom',
      sets: rawSets is List
          ? rawSets.asMap().entries.map((entry) {
              return PlyometricSet.fromJson(
                _map(entry.value),
                fallbackSet: entry.key + 1,
              );
            }).toList()
          : const [],
      direction: _string(json['direction']),
      unilateralMode:
          json['unilateralMode']?.toString() ?? UnilateralMode.bilateral,
      notes: _string(json['notes']),
    );
  }

  int get totalContacts =>
      sets.fold(0, (sum, set) => sum + set.effectiveContacts);

  int get totalReps => sets.fold(0, (sum, set) => sum + (set.reps ?? 0));

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'type': type,
        'sets': sets.map((set) => set.toJson()).toList(),
        'direction': direction,
        'unilateralMode': unilateralMode,
        'notes': notes,
      };
}

class SpeedAgilityDrill {
  final String name;
  final String type;
  final int? sets;
  final int? reps;
  final double? distanceM;
  final double? timeSeconds;
  final int? restSeconds;
  final String? startType;
  final String? surface;
  final List<String> equipment;
  final String? notes;

  const SpeedAgilityDrill({
    required this.name,
    required this.type,
    this.sets,
    this.reps,
    this.distanceM,
    this.timeSeconds,
    this.restSeconds,
    this.startType,
    this.surface,
    this.equipment = const [],
    this.notes,
  });

  factory SpeedAgilityDrill.fromJson(Map<String, dynamic> json) {
    return SpeedAgilityDrill(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'custom',
      sets: _int(json['sets']),
      reps: _int(json['reps']),
      distanceM: _double(json['distanceM']),
      timeSeconds: _double(json['timeSeconds']),
      restSeconds: _int(json['restSeconds']),
      startType: _string(json['startType']),
      surface: _string(json['surface']),
      equipment:
          (json['equipment'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      notes: _string(json['notes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'sets': sets,
        'reps': reps,
        'distanceM': distanceM,
        'timeSeconds': timeSeconds,
        'restSeconds': restSeconds,
        'startType': startType,
        'surface': surface,
        'equipment': equipment,
        'notes': notes,
      };
}

class EnduranceMetrics {
  final int? durationSeconds;
  final double? distanceKm;
  final String? avgPace;
  final double? avgSpeed;
  final int? avgHr;
  final int? maxHr;
  final int zone23Seconds;
  final int zone45Seconds;
  final double? elevationGainM;
  final int? calories;
  final String? surface;
  final String? notes;
  final String? importedSource;
  final bool isImported;
  final bool isManuallyEdited;

  const EnduranceMetrics({
    this.durationSeconds,
    this.distanceKm,
    this.avgPace,
    this.avgSpeed,
    this.avgHr,
    this.maxHr,
    this.zone23Seconds = 0,
    this.zone45Seconds = 0,
    this.elevationGainM,
    this.calories,
    this.surface,
    this.notes,
    this.importedSource,
    this.isImported = false,
    this.isManuallyEdited = false,
  });

  factory EnduranceMetrics.fromJson(Map<String, dynamic> json) {
    return EnduranceMetrics(
      durationSeconds: _int(json['durationSeconds']),
      distanceKm: _double(json['distanceKm']),
      avgPace: _string(json['avgPace']),
      avgSpeed: _double(json['avgSpeed']),
      avgHr: _int(json['avgHr']),
      maxHr: _int(json['maxHr']),
      zone23Seconds: _int(json['zone23Seconds']) ?? 0,
      zone45Seconds: _int(json['zone45Seconds']) ?? 0,
      elevationGainM: _double(json['elevationGainM']),
      calories: _int(json['calories']),
      surface: _string(json['surface']),
      notes: _string(json['notes']),
      importedSource: _string(json['importedSource']),
      isImported: json['isImported'] == true,
      isManuallyEdited: json['isManuallyEdited'] == true,
    );
  }

  factory EnduranceMetrics.fromSessionDetails(
    Map<String, dynamic> details, {
    int? durationSeconds,
  }) {
    final zoneSeconds = _intList(details['hr_zones_seconds']);
    final legacyZoneMinutes = _intList(details['hr_zones']);
    final hasStructuredZones = zoneSeconds.length >= 6;
    final zone23 = hasStructuredZones
        ? _sumIndexes(zoneSeconds, const [2, 3])
        : _sumIndexes(legacyZoneMinutes, const [1, 2]) * 60;
    final zone45 = hasStructuredZones
        ? _sumIndexes(zoneSeconds, const [4, 5])
        : _sumIndexes(legacyZoneMinutes, const [3, 4]) * 60;

    return EnduranceMetrics(
      durationSeconds:
          _int(details['active_duration_seconds']) ?? durationSeconds,
      distanceKm: _double(details['distance_km']) ??
          (_double(details['distance_meters']) == null
              ? _distanceStringToKm(details['distance'])
              : _double(details['distance_meters'])! / 1000),
      avgPace: _string(details['avgPace'] ?? details['pace']),
      avgSpeed: _double(details['avg_speed_kmh'] ?? details['avgSpeed']),
      avgHr: _int(details['avg_hr'] ?? details['avgHeartRate']),
      maxHr: _int(details['max_hr'] ?? details['maxHeartRate']),
      zone23Seconds: zone23,
      zone45Seconds: zone45,
      elevationGainM: _double(details['elevation_meters']) ??
          _distanceStringToMeters(details['elevation']),
      calories: _int(details['energy_total_kcal'] ?? details['calories']),
      surface: _string(details['surface']),
      notes: _string(details['notes']),
      importedSource: _string(details['source_name']),
      isImported: details['source'] == 'health_sync' ||
          details['source'] == ActivitySource.imported,
      isManuallyEdited: details['isManuallyEdited'] == true ||
          details['manuallyEdited'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'durationSeconds': durationSeconds,
        'distanceKm': distanceKm,
        'avgPace': avgPace,
        'avgSpeed': avgSpeed,
        'avgHr': avgHr,
        'maxHr': maxHr,
        'zone23Seconds': zone23Seconds,
        'zone45Seconds': zone45Seconds,
        'elevationGainM': elevationGainM,
        'calories': calories,
        'surface': surface,
        'notes': notes,
        'importedSource': importedSource,
        'isImported': isImported,
        'isManuallyEdited': isManuallyEdited,
      };
}

class TrainingBlock {
  final String id;
  final String type;
  final String name;
  final List<ExerciseEntry> exercises;
  final List<PlyometricEntry> plyometrics;
  final List<SpeedAgilityDrill> drills;
  final EnduranceMetrics? endurance;
  final Map<String, dynamic> metrics;
  final String? notes;

  const TrainingBlock({
    required this.id,
    required this.type,
    required this.name,
    this.exercises = const [],
    this.plyometrics = const [],
    this.drills = const [],
    this.endurance,
    this.metrics = const {},
    this.notes,
  });

  factory TrainingBlock.fromJson(Map<String, dynamic> json) {
    return TrainingBlock(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? TrainingBlockType.note,
      name: json['name']?.toString() ?? '',
      exercises: _mapList(json['exercises'])
          .map((item) => ExerciseEntry.fromJson(item))
          .toList(),
      plyometrics: _mapList(json['plyometrics'])
          .map((item) => PlyometricEntry.fromJson(item))
          .toList(),
      drills: _mapList(json['drills'])
          .map((item) => SpeedAgilityDrill.fromJson(item))
          .toList(),
      endurance: json['endurance'] is Map
          ? EnduranceMetrics.fromJson(_map(json['endurance']))
          : null,
      metrics: _map(json['metrics']),
      notes: _string(json['notes']),
    );
  }

  TrainingBlock deepCopy() => TrainingBlock.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
        'plyometrics': plyometrics.map((entry) => entry.toJson()).toList(),
        'drills': drills.map((drill) => drill.toJson()).toList(),
        'endurance': endurance?.toJson(),
        'metrics': _deepCopy(metrics),
        'notes': notes,
      };
}

class TrainingActivity {
  final String id;
  final String? athleteId;
  final String? coachId;
  final String? teamId;
  final List<String> teamIds;
  final String source;
  final String status;
  final String category;
  final String? prepType;
  final bool? usesPhases;
  final String? sportType;
  final String title;
  final String date;
  final String startTime;
  final String endTime;
  final String duration;
  final String? location;
  final int? rpe;
  final String? pain;
  final String? notes;
  final bool athleteModified;
  final bool createdByCoach;
  final String? linkedCoachEventId;
  final List<TrainingBlock> blocks;

  const TrainingActivity({
    required this.id,
    this.athleteId,
    this.coachId,
    this.teamId,
    this.teamIds = const [],
    required this.source,
    required this.status,
    required this.category,
    this.prepType,
    this.usesPhases,
    this.sportType,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.location,
    this.rpe,
    this.pain,
    this.notes,
    this.athleteModified = false,
    this.createdByCoach = false,
    this.linkedCoachEventId,
    this.blocks = const [],
  });

  factory TrainingActivity.fromJson(Map<String, dynamic> json) {
    return TrainingActivity(
      id: json['id']?.toString() ?? '',
      athleteId: _string(json['athleteId']),
      coachId: _string(json['coachId']),
      teamId: _string(json['teamId']),
      teamIds:
          (json['teamIds'] as List?)?.map((item) => item.toString()).toList() ??
              const [],
      source: json['source']?.toString() ?? ActivitySource.athlete,
      status: json['status']?.toString() ?? ActivityStatus.completed,
      category: json['category']?.toString() ?? ActivityCategory.other,
      prepType: _string(json['prepType']),
      usesPhases:
          json['usesPhases'] is bool ? json['usesPhases'] as bool : null,
      sportType: _string(json['sportType']),
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '0',
      location: _string(json['location']),
      rpe: _int(json['rpe']),
      pain: _string(json['pain']),
      notes: _string(json['notes']),
      athleteModified: json['athleteModified'] == true,
      createdByCoach: json['createdByCoach'] == true,
      linkedCoachEventId: _string(json['linkedCoachEventId']),
      blocks: _mapList(json['blocks'])
          .map((item) => TrainingBlock.fromJson(item))
          .toList(),
    );
  }

  factory TrainingActivity.fromTrainingSession(
    TrainingSession session, {
    String? athleteId,
    String? title,
    String? coachId,
    String? teamId,
    List<String> teamIds = const [],
    String? status,
  }) {
    final details = _map(session.details);
    final source = _sourceFromDetails(details);
    final category = details['activityCategory']?.toString() ??
        _categoryFromSportId(session.sportId, details);
    final blocks = _blocksFromDetails(session, details, category);
    final hasPhaseBlocks =
        blocks.any((block) => block.metrics['phase'] != null);

    return TrainingActivity(
      id: session.id,
      athleteId: athleteId,
      coachId: coachId,
      teamId: teamId,
      teamIds: teamIds,
      source: source,
      status:
          status ?? details['status']?.toString() ?? ActivityStatus.completed,
      category: category,
      prepType:
          _string(details['prepType']) ?? _prepTypeFromSportId(session.sportId),
      usesPhases: details['usesPhases'] is bool
          ? details['usesPhases'] as bool
          : hasPhaseBlocks
              ? true
              : null,
      sportType: session.sportId,
      title: title ?? details['title']?.toString() ?? session.sportId,
      date: session.date,
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      location: _string(details['location']),
      rpe: _int(details['rpe']) ?? session.effort,
      pain: _string(details['pain']),
      notes: _string(details['notes'] ?? details['athleteNotes']),
      athleteModified: details['athleteModified'] == true ||
          details['modifiedByAthlete'] == true,
      createdByCoach:
          details['from_calendar'] == true || source == ActivitySource.coach,
      linkedCoachEventId: session.eventId,
      blocks: blocks,
    );
  }

  TrainingActivity copyWith({
    String? id,
    String? athleteId,
    String? coachId,
    String? teamId,
    List<String>? teamIds,
    String? source,
    String? status,
    String? category,
    String? prepType,
    bool? usesPhases,
    String? sportType,
    String? title,
    String? date,
    String? startTime,
    String? endTime,
    String? duration,
    String? location,
    int? rpe,
    String? pain,
    String? notes,
    bool? athleteModified,
    bool? createdByCoach,
    String? linkedCoachEventId,
    List<TrainingBlock>? blocks,
  }) {
    return TrainingActivity(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      coachId: coachId ?? this.coachId,
      teamId: teamId ?? this.teamId,
      teamIds: teamIds ?? List<String>.from(this.teamIds),
      source: source ?? this.source,
      status: status ?? this.status,
      category: category ?? this.category,
      prepType: prepType ?? this.prepType,
      usesPhases: usesPhases ?? this.usesPhases,
      sportType: sportType ?? this.sportType,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      rpe: rpe ?? this.rpe,
      pain: pain ?? this.pain,
      notes: notes ?? this.notes,
      athleteModified: athleteModified ?? this.athleteModified,
      createdByCoach: createdByCoach ?? this.createdByCoach,
      linkedCoachEventId: linkedCoachEventId ?? this.linkedCoachEventId,
      blocks: blocks ?? this.blocks.map((block) => block.deepCopy()).toList(),
    );
  }

  Map<String, dynamic> toSessionDetails({Map<String, dynamic>? existing}) {
    final base = Map<String, dynamic>.from(existing ?? {});
    base.addAll({
      'schemaVersion': 2,
      'activityDomain':
          category == ActivityCategory.sport ? 'sport' : 'dryland',
      'activityCategory': category,
      'prepType': prepType,
      'usesPhases': usesPhases,
      'source': source,
      'status': status,
      'title': title,
      'location': location,
      'rpe': rpe,
      'pain': pain,
      'notes': notes,
      'athleteModified': athleteModified,
      'createdByCoach': createdByCoach,
      'linkedCoachEventId': linkedCoachEventId,
      'blocks': blocks.map((block) => block.toJson()).toList(),
    });
    base.removeWhere((_, value) => value == null);
    return base;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'athleteId': athleteId,
        'coachId': coachId,
        'teamId': teamId,
        'teamIds': teamIds,
        'source': source,
        'status': status,
        'category': category,
        'prepType': prepType,
        'usesPhases': usesPhases,
        'sportType': sportType,
        'title': title,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'duration': duration,
        'location': location,
        'rpe': rpe,
        'pain': pain,
        'notes': notes,
        'athleteModified': athleteModified,
        'createdByCoach': createdByCoach,
        'linkedCoachEventId': linkedCoachEventId,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };
}

class WorkoutTemplate {
  final String id;
  final String name;
  final String? description;
  final String ownerType;
  final String ownerId;
  final String? teamId;
  final String category;
  final String? sportType;
  final List<TrainingBlock> blocks;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.ownerType,
    required this.ownerId,
    this.teamId,
    required this.category,
    this.sportType,
    this.blocks = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: _string(json['description']),
      ownerType: json['ownerType']?.toString() ?? TemplateOwnerType.athlete,
      ownerId: json['ownerId']?.toString() ?? '',
      teamId: _string(json['teamId']),
      category: json['category']?.toString() ?? ActivityCategory.other,
      sportType: _string(json['sportType']),
      blocks: _mapList(json['blocks'])
          .map((item) => TrainingBlock.fromJson(item))
          .toList(),
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isArchived: json['isArchived'] == true,
    );
  }

  factory WorkoutTemplate.fromSupabaseJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: _string(json['description']),
      ownerType: json['owner_type']?.toString() ?? TemplateOwnerType.athlete,
      ownerId: json['owner_id']?.toString() ?? '',
      teamId: _string(json['team_id']),
      category: json['category']?.toString() ?? ActivityCategory.other,
      sportType: _string(json['sport_type']),
      blocks: _mapList(json['blocks'])
          .map((item) => TrainingBlock.fromJson(item))
          .toList(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isArchived: json['is_archived'] == true,
    );
  }

  factory WorkoutTemplate.fromActivity(
    TrainingActivity activity, {
    required String id,
    required String name,
    String? description,
    required String ownerType,
    required String ownerId,
    String? teamId,
    required String createdBy,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return WorkoutTemplate(
      id: id,
      name: name,
      description: description,
      ownerType: ownerType,
      ownerId: ownerId,
      teamId: teamId,
      category: activity.category,
      sportType: activity.sportType,
      blocks: activity.blocks.map((block) => block.deepCopy()).toList(),
      createdBy: createdBy,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  TrainingActivity instantiateActivity({
    required String id,
    required String athleteId,
    String? coachId,
    String? teamId,
    List<String> teamIds = const [],
    String source = ActivitySource.athlete,
    String status = ActivityStatus.completed,
    required String date,
    required String startTime,
    required String endTime,
    required String duration,
    String? title,
    String? location,
  }) {
    return TrainingActivity(
      id: id,
      athleteId: athleteId,
      coachId: coachId,
      teamId: teamId,
      teamIds: teamIds,
      source: source,
      status: status,
      category: category,
      sportType: sportType,
      title: title ?? name,
      date: date,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      location: location,
      createdByCoach: source == ActivitySource.coach,
      blocks: blocks.map((block) => block.deepCopy()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'ownerType': ownerType,
        'ownerId': ownerId,
        'teamId': teamId,
        'category': category,
        'sportType': sportType,
        'blocks': blocks.map((block) => block.toJson()).toList(),
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isArchived': isArchived,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'description': description,
        'owner_type': ownerType,
        'owner_id': ownerId,
        'team_id': teamId,
        'category': category,
        'sport_type': sportType,
        'blocks': blocks.map((block) => block.toJson()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_archived': isArchived,
      };
}

String _sourceFromDetails(Map<String, dynamic> details) {
  final source = details['source']?.toString();
  if (source == 'health_sync') return ActivitySource.imported;
  if (source == ActivitySource.coach ||
      source == ActivitySource.athlete ||
      source == ActivitySource.imported) {
    return source!;
  }
  if (details['from_calendar'] == true || details['createdByCoach'] == true) {
    return ActivitySource.coach;
  }
  return ActivitySource.athlete;
}

String _categoryFromSportId(String sportId, Map<String, dynamic> details) {
  if (details['source'] == 'health_sync') return ActivityCategory.endurance;
  if (sportId == ActivityCategory.athleticPrep || sportId == 'athletic_prep') {
    return ActivityCategory.athleticPrep;
  }
  if (sportId == 'dryland_strength') return ActivityCategory.strength;
  if (sportId == 'dryland_plyometrics') return ActivityCategory.plyometrics;
  if (sportId == 'dryland_speed_agility') {
    return ActivityCategory.speedAgility;
  }
  if (sportId == 'dryland_endurance') return ActivityCategory.endurance;
  if (sportId == 'dryland_mobility_core') return ActivityCategory.mobility;
  if (sportId == 'dryland_mixed_circuit') {
    return ActivityCategory.athleticPrep;
  }
  if (['weightlifting', 'powerlifting', 'crossfit', 'bodybuilding']
      .contains(sportId)) {
    return ActivityCategory.strength;
  }
  if ([
        'running',
        'road_running',
        'trail_running',
        'cycling',
        'road_cycling',
        'marathon',
        'triathlon',
        'rowing',
        'hiking',
        'walking',
        'cross_country_skiing',
        'swimming',
        'spinning',
      ].contains(sportId) ||
      sportId.contains('running') ||
      sportId.contains('cycling')) {
    return ActivityCategory.endurance;
  }
  if (['stretching', 'yoga', 'pilates'].contains(sportId)) {
    return ActivityCategory.mobility;
  }
  if (sportId == 'dryland') {
    return ActivityCategory.other;
  }
  return ActivityCategory.sport;
}

String? _prepTypeFromSportId(String sportId) {
  switch (sportId) {
    case 'dryland_strength':
      return DrylandPrepType.strength;
    case 'dryland_plyometrics':
      return DrylandPrepType.plyometrics;
    case 'dryland_speed_agility':
      return DrylandPrepType.speedAgility;
    case 'dryland_endurance':
      return DrylandPrepType.endurance;
    case 'dryland_mobility_core':
      return DrylandPrepType.mobilityCore;
    case 'dryland_mixed_circuit':
    case 'athletic_prep':
      return DrylandPrepType.mixedCircuit;
    default:
      return null;
  }
}

List<TrainingBlock> _blocksFromDetails(
  TrainingSession session,
  Map<String, dynamic> details,
  String category,
) {
  final structuredBlocks = _mapList(details['blocks']);
  if (structuredBlocks.isNotEmpty) {
    return structuredBlocks
        .map((item) => TrainingBlock.fromJson(item))
        .toList();
  }

  if (details['exercises'] is List) {
    return [
      TrainingBlock(
        id: 'legacy_strength_1',
        type: TrainingBlockType.strength,
        name: 'Strength',
        exercises: _mapList(details['exercises'])
            .map((item) => ExerciseEntry.fromJson(item))
            .toList(),
      ),
    ];
  }

  if (category == ActivityCategory.endurance) {
    final durationSeconds = _durationStringToSeconds(session.duration);
    return [
      TrainingBlock(
        id: 'endurance_1',
        type: TrainingBlockType.endurance,
        name: 'Endurance',
        endurance: EnduranceMetrics.fromSessionDetails(
          details,
          durationSeconds: durationSeconds,
        ),
      ),
    ];
  }

  return const [];
}

int _durationStringToSeconds(String duration) {
  final trimmed = duration.trim();
  if (trimmed.isEmpty) return 0;
  if (trimmed.contains(':')) {
    final parts =
        trimmed.split(':').map((part) => int.tryParse(part) ?? 0).toList();
    if (parts.length >= 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    if (parts.length == 2) return parts[0] * 3600 + parts[1] * 60;
  }
  final minutes = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  return minutes * 60;
}

List<int> _intList(dynamic value) {
  if (value is! List) return [];
  return value.map((item) => _int(item) ?? 0).toList();
}

int _sumIndexes(List<int> values, List<int> indexes) {
  var sum = 0;
  for (final index in indexes) {
    if (index >= 0 && index < values.length) sum += values[index];
  }
  return sum;
}

double? _distanceStringToKm(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  final amount = _double(text.replaceAll(RegExp(r'[^0-9,.]'), ''));
  if (amount == null) return null;
  return text.toLowerCase().contains(' m') && !text.toLowerCase().contains('km')
      ? amount / 1000
      : amount;
}

double? _distanceStringToMeters(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  final amount = _double(text.replaceAll(RegExp(r'[^0-9,.]'), ''));
  if (amount == null) return null;
  return amount;
}
