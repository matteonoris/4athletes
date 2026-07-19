import 'models.dart';
import 'training_activity_models.dart';

class WorkoutStructureMode {
  static const simple = 'simple';
  static const phased = 'phased';
}

class WorkoutDataSource {
  static const manual = 'manual';
  static const planned = 'planned';
  static const imported = 'imported';
  static const merged = 'merged';
}

class RunningWorkoutMode {
  static const free = 'free';
  static const intervals = 'intervals';
  static const fartlek = 'fartlek';

  static const values = {free, intervals, fartlek};

  static bool isRunningSportId(String sportId) {
    final normalized = sportId.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'running' ||
        normalized == 'road_running' ||
        normalized == 'trail_running' ||
        normalized == 'running_treadmill' ||
        normalized == 'track_field' ||
        normalized == 'track_and_field' ||
        normalized == 'marathon' ||
        normalized.contains('running');
  }

  static String normalize(
    String? storedMode, {
    Iterable<WorkoutPhaseDraft> phases = const [],
  }) {
    final normalized = storedMode?.trim().toLowerCase();
    if (normalized == fartlek) return fartlek;
    if (normalized == intervals ||
        phases.any(
          (phase) => phase.blocks.any(
            (block) => block.kind == WorkoutBlockKind.interval,
          ),
        )) {
      return intervals;
    }
    return free;
  }
}

class RunningMetricSource {
  static const manual = 'manual';
  static const derived = 'derived';
  static const imported = 'imported';
}

class RunningSummaryDraft {
  final double? distanceMeters;
  final int? avgPaceSecondsPerKm;
  final double? avgSpeedKmh;
  final String source;

  const RunningSummaryDraft({
    this.distanceMeters,
    this.avgPaceSecondsPerKm,
    this.avgSpeedKmh,
    this.source = RunningMetricSource.manual,
  });

  bool get hasDistance => distanceMeters != null && distanceMeters! > 0;

  RunningSummaryDraft copyWith({
    double? distanceMeters,
    bool clearDistance = false,
    int? avgPaceSecondsPerKm,
    bool clearPace = false,
    double? avgSpeedKmh,
    bool clearSpeed = false,
    String? source,
  }) {
    return RunningSummaryDraft(
      distanceMeters:
          clearDistance ? null : distanceMeters ?? this.distanceMeters,
      avgPaceSecondsPerKm:
          clearPace ? null : avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
      avgSpeedKmh: clearSpeed ? null : avgSpeedKmh ?? this.avgSpeedKmh,
      source: source ?? this.source,
    );
  }

  RunningSummaryDraft derivedForDuration(int durationSeconds) {
    if (!hasDistance || durationSeconds <= 0) {
      return copyWith(clearPace: true, clearSpeed: true);
    }
    final distanceKm = distanceMeters! / 1000;
    final pace = (durationSeconds / distanceKm).round();
    final speed = distanceKm / (durationSeconds / 3600);
    return RunningSummaryDraft(
      distanceMeters: distanceMeters,
      avgPaceSecondsPerKm: pace,
      avgSpeedKmh: double.parse(speed.toStringAsFixed(2)),
      source: source == RunningMetricSource.imported
          ? RunningMetricSource.imported
          : RunningMetricSource.derived,
    );
  }

  factory RunningSummaryDraft.fromJson(Map<String, dynamic> json) {
    return RunningSummaryDraft(
      distanceMeters: _asDouble(json['distanceMeters']),
      avgPaceSecondsPerKm: _asInt(json['avgPaceSecondsPerKm']),
      avgSpeedKmh: _asDouble(json['avgSpeedKmh']),
      source: json['source']?.toString() ?? RunningMetricSource.manual,
    );
  }

  Map<String, dynamic> toJson() => {
        'distanceMeters': distanceMeters,
        'avgPaceSecondsPerKm': avgPaceSecondsPerKm,
        'avgSpeedKmh': avgSpeedKmh,
        'source': source,
      }..removeWhere((_, value) => value == null);
}

class WorkoutBlockKind {
  static const exercise = 'exercise';
  static const exerciseSets = 'exercise_sets';
  static const sport = 'sport';
  static const interval = 'interval';
  static const circuit = 'circuit';
  static const timed = 'timed';
  static const recovery = 'recovery';
  static const note = 'note';

  static const values = [
    exercise,
    exerciseSets,
    sport,
    interval,
    circuit,
    timed,
    recovery,
    note,
  ];

  static String label(String value) => switch (value) {
        exercise => 'Esercizio',
        exerciseSets => 'Esercizio con serie',
        sport => 'Sport / attivita continua',
        interval => 'Intervallo',
        circuit => 'Circuito',
        timed => 'Blocco a tempo',
        recovery => 'Recupero',
        note => 'Nota testuale',
        _ => 'Blocco',
      };
}

class WorkoutInvitationStatus {
  static const invited = 'invited';
  static const confirmed = 'confirmed';
  static const declined = 'declined';
}

class WorkoutAttendanceStatus {
  static const pending = 'pending';
  static const present = 'present';
  static const absent = 'absent';
}

class WorkoutCompletionStatus {
  static const pending = 'pending';
  static const completed = 'completed';
}

class WorkoutParticipant {
  final String athleteId;
  final String? name;
  final String invitationStatus;
  final String attendanceStatus;
  final String completionStatus;
  final String? personalNotes;

  const WorkoutParticipant({
    required this.athleteId,
    this.name,
    this.invitationStatus = WorkoutInvitationStatus.invited,
    this.attendanceStatus = WorkoutAttendanceStatus.pending,
    this.completionStatus = WorkoutCompletionStatus.pending,
    this.personalNotes,
  });

  factory WorkoutParticipant.fromJson(Map<String, dynamic> json) {
    return WorkoutParticipant(
      athleteId: json['athleteId']?.toString() ?? '',
      name: json['name']?.toString(),
      invitationStatus: json['invitationStatus']?.toString() ??
          WorkoutInvitationStatus.invited,
      attendanceStatus: json['attendanceStatus']?.toString() ??
          WorkoutAttendanceStatus.pending,
      completionStatus: json['completionStatus']?.toString() ??
          WorkoutCompletionStatus.pending,
      personalNotes: json['personalNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'athleteId': athleteId,
        'name': name,
        'invitationStatus': invitationStatus,
        'attendanceStatus': attendanceStatus,
        'completionStatus': completionStatus,
        'personalNotes': personalNotes,
      }..removeWhere((_, value) => value == null);
}

class ExternalWorkoutLinkDraft {
  final String provider;
  final String externalActivityId;
  final String? sourceSessionId;
  final DateTime? importedAt;
  final Map<String, dynamic> metadata;

  const ExternalWorkoutLinkDraft({
    required this.provider,
    required this.externalActivityId,
    this.sourceSessionId,
    this.importedAt,
    this.metadata = const {},
  });

  factory ExternalWorkoutLinkDraft.fromJson(Map<String, dynamic> json) {
    return ExternalWorkoutLinkDraft(
      provider: json['provider']?.toString() ?? 'health',
      externalActivityId: json['externalActivityId']?.toString() ?? '',
      sourceSessionId: json['sourceSessionId']?.toString(),
      importedAt: DateTime.tryParse(json['importedAt']?.toString() ?? ''),
      metadata: _stringMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'externalActivityId': externalActivityId,
        'sourceSessionId': sourceSessionId,
        'importedAt': importedAt?.toIso8601String(),
        'metadata': metadata,
      }..removeWhere((_, value) => value == null);
}

class WorkoutBlockDraft {
  final String id;
  final String kind;
  final String title;
  final int order;
  final bool isCompleted;
  final Map<String, dynamic> fields;
  final List<WorkoutBlockDraft> children;

  const WorkoutBlockDraft({
    required this.id,
    required this.kind,
    required this.title,
    required this.order,
    this.isCompleted = false,
    this.fields = const {},
    this.children = const [],
  });

  bool get isValid {
    if (title.trim().isEmpty) return false;
    if (kind == WorkoutBlockKind.circuit) return children.isNotEmpty;
    if (kind == WorkoutBlockKind.note) {
      return (fields['notes']?.toString().trim().isNotEmpty ?? false);
    }
    return true;
  }

  WorkoutBlockDraft copyWith({
    String? id,
    String? kind,
    String? title,
    int? order,
    bool? isCompleted,
    Map<String, dynamic>? fields,
    List<WorkoutBlockDraft>? children,
  }) {
    return WorkoutBlockDraft(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
      fields: fields ?? Map<String, dynamic>.from(this.fields),
      children:
          children ?? this.children.map((item) => item.copyWith()).toList(),
    );
  }

  factory WorkoutBlockDraft.fromJson(Map<String, dynamic> json) {
    return WorkoutBlockDraft(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? WorkoutBlockKind.note,
      title: json['title']?.toString() ?? '',
      order: _asInt(json['order']) ?? 0,
      isCompleted: json['isCompleted'] == true,
      fields: _stringMap(json['fields']),
      children:
          _mapList(json['children']).map(WorkoutBlockDraft.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'order': order,
        'isCompleted': isCompleted,
        'fields': fields,
        'children': children.map((item) => item.toJson()).toList(),
      };
}

class WorkoutPhaseDraft {
  final String type;
  final String? title;
  final String? notes;
  final bool isEnabled;
  final List<WorkoutBlockDraft> blocks;

  const WorkoutPhaseDraft({
    required this.type,
    this.title,
    this.notes,
    this.isEnabled = true,
    this.blocks = const [],
  });

  bool get isValid {
    if (!isEnabled) return type != TrainingPhase.main;
    if (type == TrainingPhase.main && blocks.isEmpty) return false;
    return blocks.every((block) => block.isValid);
  }

  WorkoutPhaseDraft copyWith({
    String? type,
    String? title,
    String? notes,
    bool? isEnabled,
    List<WorkoutBlockDraft>? blocks,
  }) {
    return WorkoutPhaseDraft(
      type: type ?? this.type,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isEnabled: isEnabled ?? this.isEnabled,
      blocks: blocks ?? this.blocks.map((item) => item.copyWith()).toList(),
    );
  }

  factory WorkoutPhaseDraft.fromJson(Map<String, dynamic> json) {
    return WorkoutPhaseDraft(
      type: TrainingPhase.normalize(json['type']),
      title: json['title']?.toString(),
      notes: json['notes']?.toString(),
      isEnabled: json['isEnabled'] != false,
      blocks: _mapList(json['blocks']).map(WorkoutBlockDraft.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'notes': notes,
        'isEnabled': isEnabled,
        'blocks': blocks.map((item) => item.toJson()).toList(),
      }..removeWhere((_, value) => value == null);
}

class WorkoutDraft {
  static const schemaVersion = 4;

  final String id;
  final String? createdByUserId;
  final String creatorRole;
  final String? athleteOwnerId;
  final String? teamId;
  final String title;
  final DateTime date;
  final String plannedStartTime;
  final String? plannedEndTime;
  final String? actualStartTime;
  final String? actualEndTime;
  final int? plannedDurationMinutes;
  final int? actualDurationMinutes;
  final String? location;
  final String? notes;
  final String activityId;
  final String activityName;
  final String activityCategory;
  final String editorKind;
  final String? activityMode;
  final String? legacyActivityMode;
  final String? protocolId;
  final String? protocolName;
  final String status;
  final String structureMode;
  final String source;
  final int sessionRpe;
  final RunningSummaryDraft? runningSummary;
  final List<WorkoutPhaseDraft> phases;
  final List<WorkoutParticipant> participants;
  final ExternalWorkoutLinkDraft? externalLink;
  final String? legacyActivityType;
  final DateTime updatedAt;

  const WorkoutDraft({
    required this.id,
    this.createdByUserId,
    this.creatorRole = 'athlete',
    this.athleteOwnerId,
    this.teamId,
    required this.title,
    required this.date,
    required this.plannedStartTime,
    this.plannedEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.plannedDurationMinutes,
    this.actualDurationMinutes,
    this.location,
    this.notes,
    required this.activityId,
    required this.activityName,
    required this.activityCategory,
    required this.editorKind,
    this.activityMode,
    this.legacyActivityMode,
    this.protocolId,
    this.protocolName,
    this.status = ActivityStatus.completed,
    this.structureMode = WorkoutStructureMode.simple,
    this.source = WorkoutDataSource.manual,
    this.sessionRpe = 5,
    this.runningSummary,
    this.phases = const [],
    this.participants = const [],
    this.externalLink,
    this.legacyActivityType,
    required this.updatedAt,
  });

  bool get isPlanned => status == ActivityStatus.planned;

  bool get isRunning => RunningWorkoutMode.isRunningSportId(activityId);

  String get effectiveStartTime =>
      isPlanned ? plannedStartTime : (actualStartTime ?? plannedStartTime);

  String get effectiveEndTime => isPlanned
      ? (plannedEndTime ??
          _addMinutes(plannedStartTime, plannedDurationMinutes ?? 60))
      : (actualEndTime ??
          plannedEndTime ??
          _addMinutes(
            actualStartTime ?? plannedStartTime,
            actualDurationMinutes ?? plannedDurationMinutes ?? 60,
          ));

  int get effectiveDurationMinutes {
    final clockDuration = _minutesBetweenClocks(
      effectiveStartTime,
      effectiveEndTime,
    );
    final hasExplicitEnd = isPlanned
        ? plannedEndTime != null
        : actualEndTime != null || plannedEndTime != null;
    if (hasExplicitEnd || clockDuration > 0) return clockDuration;
    return (isPlanned ? plannedDurationMinutes : actualDurationMinutes) ??
        plannedDurationMinutes ??
        actualDurationMinutes ??
        60;
  }

  List<String> validateForStep(int step) {
    final errors = <String>[];
    if (step >= 2) {
      if (title.trim().isEmpty) {
        errors.add('Inserisci il nome dell allenamento.');
      }
      if (effectiveDurationMinutes <= 0) {
        errors.add('La durata deve essere maggiore di zero.');
      }
      if (isRunning &&
          runningSummary?.distanceMeters != null &&
          runningSummary!.distanceMeters! <= 0) {
        errors.add('La distanza deve essere maggiore di zero.');
      }
    }
    if (step >= 4) {
      if (isRunning) {
        if (structureMode == WorkoutStructureMode.simple) return errors;
        final main = phases
            .where((phase) => phase.type == TrainingPhase.main)
            .firstOrNull;
        if (main == null || main.blocks.isEmpty) {
          errors.add('Compila il lavoro principale.');
          return errors;
        }
        if (activityMode == RunningWorkoutMode.intervals) {
          for (final block in main.blocks) {
            final intervalError = _validateRunningInterval(block);
            if (intervalError != null) {
              errors.add(intervalError);
              break;
            }
          }
        } else {
          final hasMainContent = main.blocks.any(_hasRunningPhaseContent);
          if (!hasMainContent) {
            errors.add('Compila il lavoro principale.');
          } else if (activityMode == RunningWorkoutMode.fartlek &&
              !main.blocks.any(
                (block) =>
                    (block.fields['notes']?.toString().trim().isNotEmpty ??
                        false),
              )) {
            errors.add('Descrivi le variazioni del Fartlek.');
          }
        }
        for (final phase in phases.where(
          (phase) => phase.isEnabled && phase.type != TrainingPhase.main,
        )) {
          if (phase.blocks.isEmpty ||
              !phase.blocks.any(_hasRunningPhaseContent)) {
            errors.add('Compila ${TrainingPhase.label(phase.type)}.');
            break;
          }
        }
        return errors;
      }
      final main = phases.where((phase) => phase.type == TrainingPhase.main);
      if (main.isEmpty || main.first.blocks.isEmpty) {
        errors.add('Aggiungi almeno un blocco al lavoro principale.');
      }
      for (final phase in phases.where((phase) => phase.isEnabled)) {
        if (!phase.isValid) {
          errors.add(
              'Controlla i blocchi di ${TrainingPhase.label(phase.type)}.');
        }
      }
    }
    return errors;
  }

  static bool _hasRunningPhaseContent(WorkoutBlockDraft block) {
    final duration = _asDouble(block.fields['durationSeconds']) ?? 0;
    final distance = _asDouble(block.fields['distanceMeters']) ?? 0;
    final notes = block.fields['notes']?.toString().trim() ?? '';
    return duration > 0 || distance > 0 || notes.isNotEmpty;
  }

  static String? _validateRunningInterval(WorkoutBlockDraft block) {
    if (block.kind != WorkoutBlockKind.interval) {
      return 'Il lavoro principale può contenere solo blocchi di ripetute.';
    }
    final workUnit = block.fields['workUnit']?.toString();
    final workValue = workUnit == 'distance'
        ? _asDouble(block.fields['workDistanceMeters'])
        : _asDouble(block.fields['workSeconds']);
    final repetitions = _asInt(block.fields['repetitions']) ?? 0;
    final series = _asInt(block.fields['series']) ?? 0;
    if (!const {'time', 'distance'}.contains(workUnit) ||
        workValue == null ||
        workValue <= 0) {
      return 'Indica se le ripetute sono basate su tempo o distanza.';
    }
    if (repetitions < 1 || series < 1) {
      return 'Ripetizioni e serie devono essere almeno 1.';
    }
    if (repetitions > 1) {
      final recoveryUnit = block.fields['repRecoveryUnit']?.toString();
      final recoveryValue = recoveryUnit == 'distance'
          ? _asDouble(block.fields['repRecoveryMeters'])
          : _asDouble(block.fields['repRecoverySeconds']);
      if (!const {'time', 'distance'}.contains(recoveryUnit) ||
          recoveryValue == null ||
          recoveryValue <= 0) {
        return 'Inserisci il recupero tra le ripetute.';
      }
    }
    if (series > 1 &&
        (_asDouble(block.fields['seriesRecoverySeconds']) ?? 0) <= 0) {
      return 'Inserisci la pausa tra le serie.';
    }
    return null;
  }

  WorkoutDraft copyWith({
    String? id,
    String? createdByUserId,
    String? creatorRole,
    String? athleteOwnerId,
    String? teamId,
    String? title,
    DateTime? date,
    String? plannedStartTime,
    String? plannedEndTime,
    String? actualStartTime,
    String? actualEndTime,
    int? plannedDurationMinutes,
    int? actualDurationMinutes,
    String? location,
    bool clearLocation = false,
    String? notes,
    bool clearNotes = false,
    String? activityId,
    String? activityName,
    String? activityCategory,
    String? editorKind,
    String? activityMode,
    String? legacyActivityMode,
    bool clearLegacyActivityMode = false,
    String? protocolId,
    String? protocolName,
    bool clearProtocol = false,
    String? status,
    String? structureMode,
    String? source,
    int? sessionRpe,
    RunningSummaryDraft? runningSummary,
    bool clearRunningSummary = false,
    List<WorkoutPhaseDraft>? phases,
    List<WorkoutParticipant>? participants,
    ExternalWorkoutLinkDraft? externalLink,
    bool clearExternalLink = false,
    String? legacyActivityType,
    DateTime? updatedAt,
  }) {
    return WorkoutDraft(
      id: id ?? this.id,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      creatorRole: creatorRole ?? this.creatorRole,
      athleteOwnerId: athleteOwnerId ?? this.athleteOwnerId,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      date: date ?? this.date,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      location: clearLocation ? null : location ?? this.location,
      notes: clearNotes ? null : notes ?? this.notes,
      activityId: activityId ?? this.activityId,
      activityName: activityName ?? this.activityName,
      activityCategory: activityCategory ?? this.activityCategory,
      editorKind: editorKind ?? this.editorKind,
      activityMode: activityMode ?? this.activityMode,
      legacyActivityMode: clearLegacyActivityMode
          ? null
          : legacyActivityMode ?? this.legacyActivityMode,
      protocolId: clearProtocol ? null : protocolId ?? this.protocolId,
      protocolName: clearProtocol ? null : protocolName ?? this.protocolName,
      status: status ?? this.status,
      structureMode: structureMode ?? this.structureMode,
      source: source ?? this.source,
      sessionRpe: (sessionRpe ?? this.sessionRpe).clamp(1, 10),
      runningSummary:
          clearRunningSummary ? null : runningSummary ?? this.runningSummary,
      phases: phases ?? this.phases.map((phase) => phase.copyWith()).toList(),
      participants:
          participants ?? List<WorkoutParticipant>.from(this.participants),
      externalLink:
          clearExternalLink ? null : externalLink ?? this.externalLink,
      legacyActivityType: legacyActivityType ?? this.legacyActivityType,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory WorkoutDraft.fromJson(Map<String, dynamic> json) {
    final activityId = json['activityId']?.toString() ?? 'other';
    final phases =
        _mapList(json['phases']).map(WorkoutPhaseDraft.fromJson).toList();
    final storedMode = json['activityMode']?.toString();
    final isRunning = RunningWorkoutMode.isRunningSportId(activityId);
    final activityMode = isRunning
        ? RunningWorkoutMode.normalize(storedMode, phases: phases)
        : storedMode;
    final legacyActivityMode = json['legacyActivityMode']?.toString() ??
        (isRunning &&
                storedMode != null &&
                !RunningWorkoutMode.values.contains(storedMode)
            ? storedMode
            : null);
    return WorkoutDraft(
      id: json['id']?.toString() ?? '',
      createdByUserId: json['createdByUserId']?.toString(),
      creatorRole: json['creatorRole']?.toString() ?? 'athlete',
      athleteOwnerId: json['athleteOwnerId']?.toString(),
      teamId: json['teamId']?.toString(),
      title: json['title']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      plannedStartTime: json['plannedStartTime']?.toString() ?? '09:00',
      plannedEndTime: json['plannedEndTime']?.toString(),
      actualStartTime: json['actualStartTime']?.toString(),
      actualEndTime: json['actualEndTime']?.toString(),
      plannedDurationMinutes: _asInt(json['plannedDurationMinutes']),
      actualDurationMinutes: _asInt(json['actualDurationMinutes']),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      activityId: activityId,
      activityName: json['activityName']?.toString() ?? 'Altro',
      activityCategory:
          json['activityCategory']?.toString() ?? ActivityCategory.other,
      editorKind: json['editorKind']?.toString() ?? 'universal',
      activityMode: activityMode,
      legacyActivityMode: legacyActivityMode,
      protocolId: json['protocolId']?.toString(),
      protocolName: json['protocolName']?.toString(),
      status: json['status']?.toString() ?? ActivityStatus.completed,
      structureMode:
          json['structureMode']?.toString() ?? WorkoutStructureMode.simple,
      source: json['source']?.toString() ?? WorkoutDataSource.manual,
      sessionRpe: (_asInt(json['sessionRpe'] ?? json['rpe']) ?? 5).clamp(1, 10),
      runningSummary: json['runningSummary'] is Map
          ? RunningSummaryDraft.fromJson(_stringMap(json['runningSummary']))
          : null,
      phases: phases,
      participants: _mapList(json['participants'])
          .map(WorkoutParticipant.fromJson)
          .toList(),
      externalLink: json['externalLink'] is Map
          ? ExternalWorkoutLinkDraft.fromJson(_stringMap(json['externalLink']))
          : null,
      legacyActivityType: json['legacyActivityType']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'createdByUserId': createdByUserId,
        'creatorRole': creatorRole,
        'athleteOwnerId': athleteOwnerId,
        'teamId': teamId,
        'title': title,
        'date': date.toIso8601String().split('T').first,
        'plannedStartTime': plannedStartTime,
        'plannedEndTime': plannedEndTime,
        'actualStartTime': actualStartTime,
        'actualEndTime': actualEndTime,
        'plannedDurationMinutes': plannedDurationMinutes,
        'actualDurationMinutes': actualDurationMinutes,
        'location': location,
        'notes': notes,
        'activityId': activityId,
        'activityName': activityName,
        'activityCategory': activityCategory,
        'editorKind': editorKind,
        'activityMode': activityMode,
        'legacyActivityMode': legacyActivityMode,
        'protocolId': protocolId,
        'protocolName': protocolName,
        'status': status,
        'structureMode': structureMode,
        'source': source,
        'sessionRpe': sessionRpe,
        'runningSummary': runningSummary?.toJson(),
        'phases': phases.map((phase) => phase.toJson()).toList(),
        'participants': participants.map((item) => item.toJson()).toList(),
        'externalLink': externalLink?.toJson(),
        'legacyActivityType': legacyActivityType,
        'updatedAt': updatedAt.toIso8601String(),
      }..removeWhere((_, value) => value == null);

  List<TrainingBlock> toLegacyBlocks() {
    if (isRunning && structureMode == WorkoutStructureMode.simple) {
      return const [];
    }
    final blocks = <TrainingBlock>[];
    for (final phase in phases.where((phase) => phase.isEnabled)) {
      for (final block in phase.blocks) {
        final metrics = <String, dynamic>{
          'phase': phase.type,
          'blockKind': block.kind,
          'order': block.order,
          'isCompleted': block.isCompleted,
          ...block.fields,
          if (block.children.isNotEmpty)
            'children': block.children.map((item) => item.toJson()).toList(),
        };
        final blockActivityCategory =
            block.fields['activityCategory']?.toString();
        final isSpeedDrill =
            blockActivityCategory == ActivityCategory.speedAgility ||
                block.fields['trackingMode'] == ActivityCategory.speedAgility;
        final type = switch (block.kind) {
          WorkoutBlockKind.exercise ||
          WorkoutBlockKind.exerciseSets =>
            isSpeedDrill
                ? TrainingBlockType.speedAgility
                : TrainingBlockType.strength,
          WorkoutBlockKind.sport ||
          WorkoutBlockKind.interval =>
            TrainingBlockType.endurance,
          WorkoutBlockKind.circuit => TrainingBlockType.circuit,
          _ => TrainingBlockType.note,
        };
        final exercise = !isSpeedDrill &&
                (block.kind == WorkoutBlockKind.exercise ||
                    block.kind == WorkoutBlockKind.exerciseSets)
            ? _exerciseFromBlock(block)
            : null;
        final drill = isSpeedDrill ? _speedDrillFromBlock(block) : null;
        blocks.add(TrainingBlock(
          id: block.id,
          type: type,
          name: block.title,
          exercises: exercise == null ? const [] : [exercise],
          drills: drill == null ? const [] : [drill],
          metrics: metrics,
          notes: block.fields['notes']?.toString(),
        ));
      }
    }
    return blocks;
  }

  TrainingSession toTrainingSession({String? sessionId}) {
    final dateKey = date.toIso8601String().split('T').first;
    final start = effectiveStartTime;
    final end = effectiveEndTime;
    final legacyBlocks = toLegacyBlocks();
    final activePhases =
        isRunning && structureMode == WorkoutStructureMode.simple
            ? const <WorkoutPhaseDraft>[]
            : phases;
    final normalizedRunningSummary = isRunning && runningSummary != null
        ? (runningSummary!.source == RunningMetricSource.imported
            ? runningSummary!
            : runningSummary!.derivedForDuration(
                effectiveDurationMinutes * 60,
              ))
        : runningSummary;
    final workoutDraftJson = normalizedRunningSummary == runningSummary
        ? toJson()
        : copyWith(runningSummary: normalizedRunningSummary).toJson();
    final details = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'workoutDraft': workoutDraftJson,
      'activityDomain':
          activityCategory == ActivityCategory.sport ? 'sport' : 'dryland',
      'activityCategory': activityCategory,
      'activityMode': activityMode,
      'legacyActivityMode': legacyActivityMode,
      'protocolId': protocolId,
      'protocolName': protocolName,
      'structureMode': structureMode,
      'usesPhases': structureMode == WorkoutStructureMode.phased,
      'status': status,
      'workoutSource': externalLink == null ? source : WorkoutDataSource.merged,
      'source': externalLink == null ? source : 'health_sync',
      'title': title,
      'location': location,
      'notes': notes,
      'rpe': sessionRpe,
      'plannedDurationMinutes': plannedDurationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
      'plannedStartTime': plannedStartTime,
      'plannedEndTime': plannedEndTime,
      'actualStartTime': actualStartTime,
      'actualEndTime': actualEndTime,
      'participants': participants.map((item) => item.toJson()).toList(),
      'externalLink': externalLink?.toJson(),
      'legacyActivityType': legacyActivityType,
      'blocks': legacyBlocks.map((block) => block.toJson()).toList(),
      if (normalizedRunningSummary?.hasDistance == true) ...{
        'distance_meters': normalizedRunningSummary!.distanceMeters!.round(),
        'distance':
            '${(normalizedRunningSummary.distanceMeters! / 1000).toStringAsFixed(2)} km',
        'avg_pace_sec_per_km': normalizedRunningSummary.avgPaceSecondsPerKm,
        'pace': normalizedRunningSummary.avgPaceSecondsPerKm == null
            ? null
            : '${_formatRunningPace(normalizedRunningSummary.avgPaceSecondsPerKm!)} min/km',
        'avg_speed_kmh': normalizedRunningSummary.avgSpeedKmh,
        'speed': normalizedRunningSummary.avgSpeedKmh == null
            ? null
            : '${normalizedRunningSummary.avgSpeedKmh!.toStringAsFixed(1)} km/h',
        'running_metrics_source': normalizedRunningSummary.source,
      },
      if (isPlanned)
        'prescription': {
          'startTime': plannedStartTime,
          'endTime': plannedEndTime ?? effectiveEndTime,
          'durationMinutes': plannedDurationMinutes,
          'phases': activePhases.map((phase) => phase.toJson()).toList(),
        },
      if (!isPlanned)
        'actual': {
          'startTime': actualStartTime ?? plannedStartTime,
          'endTime': actualEndTime ?? plannedEndTime ?? effectiveEndTime,
          'durationMinutes': actualDurationMinutes ?? plannedDurationMinutes,
          'phases': activePhases.map((phase) => phase.toJson()).toList(),
        },
    }..removeWhere((_, value) => value == null);
    return TrainingSession(
      id: sessionId ?? id,
      sportId: activityId,
      date: dateKey,
      startTime: start,
      endTime: end,
      duration: effectiveDurationMinutes.toString(),
      effort: sessionRpe,
      details: details,
    );
  }
}

class WorkoutProvenance {
  static bool isMerged(TrainingSession session) {
    final details = session.details ?? const <String, dynamic>{};
    final rawDraft = details['workoutDraft'];
    final draftSource = rawDraft is Map ? rawDraft['source']?.toString() : null;
    final mergedIds = details['merged_source_workout_ids'];
    return details['workoutSource'] == WorkoutDataSource.merged ||
        draftSource == WorkoutDataSource.merged ||
        details['externalLink'] != null ||
        (mergedIds is List && mergedIds.isNotEmpty);
  }

  static bool isCoachCreated(TrainingSession session) {
    final details = session.details ?? const <String, dynamic>{};
    final rawDraft = details['workoutDraft'];
    final creatorRole =
        rawDraft is Map ? rawDraft['creatorRole']?.toString() : null;
    return session.eventId != null ||
        details['from_calendar'] == true ||
        details['createdByCoach'] == true ||
        details['coachId'] != null ||
        details['source'] == ActivitySource.coach ||
        creatorRole == 'coach';
  }
}

ExerciseEntry _exerciseFromBlock(WorkoutBlockDraft block) {
  final storedSets = _mapList(block.fields['sets']);
  final legacySetCount = (_asInt(block.fields['sets']) ?? 1).clamp(1, 100);
  final parsedSets = storedSets.isNotEmpty
      ? storedSets
          .asMap()
          .entries
          .map(
            (entry) => StrengthSet.fromJson(
              entry.value,
              fallbackSet: entry.key + 1,
            ),
          )
          .toList()
      : List.generate(
          legacySetCount,
          (index) => StrengthSet(
            setNumber: index + 1,
            kg: _asDouble(block.fields['loadKg']),
            reps: _asInt(block.fields['reps']),
            percent1RM: _asDouble(block.fields['percent1RM']),
            rpe: _asDouble(block.fields['rpe']),
            rir: _asInt(block.fields['rir']),
            restSeconds: _asInt(block.fields['recoverySeconds']),
            durationSeconds: _asInt(block.fields['durationSeconds']),
            tempo: block.fields['tempo']?.toString(),
            notes: block.fields['notes']?.toString(),
            side: block.fields['side']?.toString() ?? TrainingSide.none,
          ),
        );
  return ExerciseEntry(
    exerciseId: block.fields['exerciseId']?.toString() ?? block.id,
    name: block.title,
    equipment: block.fields['equipment']?.toString(),
    variant: block.fields['variant']?.toString(),
    unilateralMode:
        block.fields['side']?.toString() ?? UnilateralMode.bilateral,
    sets: parsedSets,
  );
}

SpeedAgilityDrill _speedDrillFromBlock(WorkoutBlockDraft block) {
  final trials = _mapList(block.fields['sets'])
      .asMap()
      .entries
      .map(
        (entry) => SpeedAgilityTrial.fromJson(
          entry.value,
          fallbackTrial: entry.key + 1,
        ),
      )
      .toList();
  final distances =
      trials.map((trial) => trial.distanceM).whereType<double>().toSet();
  final times = trials
      .map((trial) => trial.timeSeconds)
      .whereType<double>()
      .where((value) => value > 0)
      .toList();
  return SpeedAgilityDrill(
    name: block.title,
    type: block.fields['speedGroup']?.toString() ?? 'custom',
    sets: trials.length,
    reps: 1,
    distanceM: distances.length == 1 ? distances.first : null,
    timeSeconds: times.isEmpty ? null : times.reduce((a, b) => a < b ? a : b),
    restSeconds: trials.isEmpty ? null : trials.first.restSeconds,
    startType: trials.isEmpty ? null : trials.first.startType,
    surface: block.fields['surface']?.toString(),
    equipment: [
      if ((block.fields['equipment']?.toString() ?? '').isNotEmpty)
        block.fields['equipment'].toString(),
      if ((block.fields['equipmentCategory']?.toString() ?? '').isNotEmpty)
        block.fields['equipmentCategory'].toString(),
    ],
    trials: trials,
    notes: block.fields['notes']?.toString(),
  );
}

String _addMinutes(String start, int minutes) {
  final parts = start.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final value =
      DateTime(2000, 1, 1, hour, minute).add(Duration(minutes: minutes));
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

int _minutesBetweenClocks(String start, String end) {
  int? minutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  final startMinutes = minutes(start);
  final endMinutes = minutes(end);
  if (startMinutes == null || endMinutes == null) return 0;
  if (startMinutes == endMinutes) return 0;
  return endMinutes > startMinutes
      ? endMinutes - startMinutes
      : (24 * 60 - startMinutes) + endMinutes;
}

String _formatRunningPace(int secondsPerKm) {
  final safeSeconds = secondsPerKm.clamp(0, 24 * 60 * 60);
  final minutes = safeSeconds ~/ 60;
  final seconds = safeSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return {};
  return value.map((key, child) => MapEntry(key.toString(), child));
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_stringMap).toList();
}

int? _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.'));
}
