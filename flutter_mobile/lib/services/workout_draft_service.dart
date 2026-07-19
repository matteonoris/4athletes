import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/exercises.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../models/workout_creation_models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/health_workout_merge_utils.dart';

class WorkoutDraftStore {
  static const _keyPrefix = 'workout_draft_v4_';
  static const _legacyKeyPrefix = 'workout_draft_v3_';

  final SharedPreferences preferences;

  const WorkoutDraftStore(this.preferences);

  String _key(String userId) => '$_keyPrefix$userId';

  String _legacyKey(String userId) => '$_legacyKeyPrefix$userId';

  Future<void> save(String userId, WorkoutDraft draft) {
    return preferences.setString(_key(userId), jsonEncode(draft.toJson()));
  }

  WorkoutDraft? load(String userId) {
    final raw = preferences.getString(_key(userId)) ??
        preferences.getString(_legacyKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return WorkoutDraft.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String userId) async {
    await preferences.remove(_key(userId));
    await preferences.remove(_legacyKey(userId));
  }
}

class CoachWorkoutEventFactory {
  static CalendarEvent create({
    required WorkoutDraft draft,
    required Team team,
    required String coachId,
    String? eventId,
  }) {
    final normalizedDraft = draft.copyWith(
      creatorRole: 'coach',
      teamId: team.id,
      source: WorkoutDataSource.planned,
    );
    final session = normalizedDraft.toTrainingSession(
      sessionId: eventId ?? normalizedDraft.id,
    );
    final plannedActivity = TrainingActivity.fromTrainingSession(
      session,
      coachId: coachId,
      teamId: team.id,
      teamIds: [team.id],
      status: normalizedDraft.status,
      title: normalizedDraft.title,
    ).copyWith(
      source: ActivitySource.coach,
      createdByCoach: true,
    );
    final isCompleted = normalizedDraft.status == ActivityStatus.completed;
    final attendees = normalizedDraft.participants.map((participant) {
      final attendanceStatus = isCompleted
          ? WorkoutAttendanceStatus.present
          : participant.attendanceStatus;
      return CoachTrainingUtils.normalizeAttendee({
        'id': participant.athleteId,
        'name': participant.name,
        'teamId': team.id,
        'teamName': team.name,
        'invitationStatus': participant.invitationStatus,
        'attendanceStatus': attendanceStatus,
        'completionStatus': isCompleted
            ? WorkoutCompletionStatus.completed
            : participant.completionStatus,
        'invitedAt': DateTime.now().toIso8601String(),
      });
    }).toList();

    return CalendarEvent(
      id: eventId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      teamId: team.id,
      type: 'training',
      title: normalizedDraft.title,
      date: normalizedDraft.date.toIso8601String().split('T').first,
      startTime: normalizedDraft.effectiveStartTime,
      endTime: normalizedDraft.effectiveEndTime,
      location: normalizedDraft.location,
      notes: normalizedDraft.notes,
      sportCategory: 'dryland',
      drylandSpecialty: normalizedDraft.activityCategory,
      technicalDetails: {
        'technicalVersion': WorkoutDraft.schemaVersion,
        'teamIds': [team.id],
        'sessionRpe': normalizedDraft.sessionRpe,
        'qualityRating': normalizedDraft.sessionRpe,
        'workoutDraft': normalizedDraft.toJson(),
        'plannedDrylandSession': plannedActivity.toJson(),
      },
      attendees: attendees,
      status: normalizedDraft.status,
    );
  }

  static TrainingSession previewSession({
    required CalendarEvent event,
    required WorkoutDraft draft,
  }) {
    final base = draft.toTrainingSession(sessionId: event.id);
    return TrainingSession(
      id: event.id,
      sportId: draft.activityId,
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      duration: base.duration,
      effort: base.effort,
      eventId: event.id,
      details: {
        ...?base.details,
        'source': ActivitySource.coach,
        'from_calendar': true,
        'createdByCoach': true,
        'linkedCoachEventId': event.id,
        'technicalDetails': event.technicalDetails,
        'plannedDrylandSession':
            event.technicalDetails?['plannedDrylandSession'],
      },
    );
  }
}

class WorkoutDraftFactory {
  static WorkoutDraft create({
    required WorkoutActivityDefinition activity,
    required String userId,
    required String creatorRole,
    WorkoutModeDefinition? mode,
    WorkoutProtocolDefinition? protocol,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final isConditioning = activity.id == 'conditioning_hiit';
    final isRunning = RunningWorkoutMode.isRunningSportId(activity.id);
    final durationMinutes = isConditioning ? 30 : 60;
    final selectedMode = mode ??
        ((isConditioning || isRunning) && activity.modes.isNotEmpty
            ? activity.modes.first
            : null);
    final phases = isRunning
        ? [
            const WorkoutPhaseDraft(
              type: TrainingPhase.warmup,
              isEnabled: false,
            ),
            WorkoutPhaseDraft(
              type: TrainingPhase.main,
              blocks: protocol == null
                  ? const []
                  : [
                      _initialBlock(
                        activity,
                        selectedMode,
                        protocol,
                        durationMinutes: durationMinutes,
                      ),
                    ],
            ),
            const WorkoutPhaseDraft(
              type: TrainingPhase.cooldown,
              isEnabled: false,
            ),
          ]
        : [
            WorkoutPhaseDraft(
              type: TrainingPhase.warmup,
              isEnabled: isConditioning,
              blocks: isConditioning
                  ? [_timedPhaseBlock(TrainingPhase.warmup, 5)]
                  : const [],
            ),
            WorkoutPhaseDraft(
              type: TrainingPhase.main,
              blocks: [
                _initialBlock(
                  activity,
                  selectedMode,
                  protocol,
                  durationMinutes: isConditioning ? 20 : durationMinutes,
                ),
              ],
            ),
            WorkoutPhaseDraft(
              type: TrainingPhase.cooldown,
              isEnabled: isConditioning,
              blocks: isConditioning
                  ? [_timedPhaseBlock(TrainingPhase.cooldown, 5)]
                  : const [],
            ),
          ];
    return WorkoutDraft(
      id: 'workout_${timestamp.microsecondsSinceEpoch}',
      createdByUserId: userId,
      creatorRole: creatorRole,
      athleteOwnerId: creatorRole == 'coach' ? null : userId,
      title: protocol?.name ?? activity.name,
      date: DateTime(timestamp.year, timestamp.month, timestamp.day),
      plannedStartTime:
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      plannedEndTime: _clockAfter(timestamp, durationMinutes),
      actualStartTime:
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      actualEndTime: _clockAfter(timestamp, durationMinutes),
      actualDurationMinutes: durationMinutes,
      activityId: activity.id,
      activityName: activity.name,
      activityCategory: activity.category,
      editorKind: activity.editorKind,
      activityMode: selectedMode?.id,
      protocolId: protocol?.id,
      protocolName: protocol?.name,
      structureMode: isConditioning ||
              (isRunning && selectedMode?.id == RunningWorkoutMode.intervals)
          ? WorkoutStructureMode.phased
          : WorkoutStructureMode.simple,
      runningSummary: isRunning ? const RunningSummaryDraft() : null,
      phases: phases,
      updatedAt: timestamp,
    );
  }

  /// Hydrates the unified editor from sessions saved by the former
  /// sport-specific forms.
  static WorkoutDraft fromTrainingSession({
    required TrainingSession session,
    required WorkoutActivityDefinition activity,
    required String userId,
    String creatorRole = 'athlete',
  }) {
    final details = Map<String, dynamic>.from(session.details ?? const {});
    final date = DateTime.tryParse(session.date) ?? DateTime.now();
    final durationMinutes = _sessionDurationMinutes(session);
    final trainingActivity = TrainingActivity.fromTrainingSession(
      session,
      title: activity.name,
    );
    final convertedPhases = _phasesFromTrainingActivity(trainingActivity);
    final hasConvertedContent = convertedPhases.any(
      (phase) => phase.blocks.isNotEmpty,
    );
    final usesPhases = details['usesPhases'] == true ||
        convertedPhases.any(
          (phase) =>
              phase.type != TrainingPhase.main && phase.blocks.isNotEmpty,
        );
    final externalLink = _externalLinkFromDetails(session, details);
    final title = details['title']?.toString().trim();
    final status = details['status']?.toString() ?? ActivityStatus.completed;
    final source = details['workoutSource']?.toString() ??
        (details['source'] == 'health_sync'
            ? WorkoutDataSource.imported
            : WorkoutDataSource.manual);
    final base = create(
      activity: activity,
      userId: userId,
      creatorRole: creatorRole,
      now: date,
    );
    final isRunning = RunningWorkoutMode.isRunningSportId(activity.id);
    final storedMode = details['activityMode']?.toString();
    final normalizedMode = isRunning
        ? RunningWorkoutMode.normalize(
            storedMode,
            phases: convertedPhases,
          )
        : storedMode;
    final legacyMode = isRunning &&
            storedMode != null &&
            !RunningWorkoutMode.values.contains(storedMode)
        ? storedMode
        : details['legacyActivityMode']?.toString();

    return base.copyWith(
      id: session.id,
      title: title == null || title.isEmpty || title == session.sportId
          ? activity.name
          : title,
      date: DateTime(date.year, date.month, date.day),
      plannedStartTime: session.startTime,
      plannedEndTime: session.endTime,
      actualStartTime: session.startTime,
      actualEndTime: session.endTime,
      plannedDurationMinutes: durationMinutes,
      actualDurationMinutes: durationMinutes,
      location: details['location']?.toString(),
      notes: (details['notes'] ?? details['athleteNotes'])?.toString(),
      activityId: activity.id,
      activityName: activity.name,
      activityCategory: activity.category,
      editorKind: activity.editorKind,
      activityMode: normalizedMode,
      legacyActivityMode: legacyMode,
      protocolId: details['protocolId']?.toString(),
      protocolName: details['protocolName']?.toString(),
      status: status,
      structureMode: usesPhases
          ? WorkoutStructureMode.phased
          : WorkoutStructureMode.simple,
      source: source,
      sessionRpe: session.effort.clamp(1, 10),
      runningSummary: isRunning ? _runningSummaryFromDetails(details) : null,
      phases: hasConvertedContent ? convertedPhases : base.phases,
      participants: _mapList(details['participants'])
          .map(WorkoutParticipant.fromJson)
          .toList(),
      externalLink: externalLink,
      legacyActivityType: session.sportId,
      updatedAt: DateTime.now(),
    );
  }

  static WorkoutDraft applyRunningImport(
    WorkoutDraft draft,
    TrainingSession imported,
  ) {
    if (!RunningWorkoutMode.isRunningSportId(draft.activityId)) return draft;
    final details = Map<String, dynamic>.from(imported.details ?? const {});
    final importedDate = DateTime.tryParse(imported.date) ?? draft.date;
    final duration = _sessionDurationMinutes(imported);
    final inferredMode = inferRunningMode(imported);
    return draft.copyWith(
      date: DateTime(importedDate.year, importedDate.month, importedDate.day),
      plannedStartTime: imported.startTime,
      plannedEndTime: imported.endTime,
      actualStartTime: imported.startTime,
      actualEndTime: imported.endTime,
      plannedDurationMinutes: duration,
      actualDurationMinutes: duration,
      activityMode: inferredMode,
      structureMode: inferredMode == RunningWorkoutMode.intervals
          ? WorkoutStructureMode.phased
          : WorkoutStructureMode.simple,
      source: WorkoutDataSource.imported,
      runningSummary: _runningSummaryFromDetails(
        details,
        source: RunningMetricSource.imported,
      ),
      phases: _emptyRunningPhases(),
    );
  }

  static String inferRunningMode(TrainingSession session) {
    final details = session.details ?? const <String, dynamic>{};
    final storedMode = details['activityMode']?.toString();
    if (storedMode != null && RunningWorkoutMode.values.contains(storedMode)) {
      return storedMode;
    }
    final searchable = [
      details['title'],
      details['notes'],
      details['workout_name'],
      details['source_workout_title'],
    ].whereType<Object>().join(' ').toLowerCase();
    if (searchable.contains('fartlek')) return RunningWorkoutMode.fartlek;
    if (searchable.contains('interval') ||
        searchable.contains('ripetut') ||
        searchable.contains('repeat')) {
      return RunningWorkoutMode.intervals;
    }
    final rawSegments = details['imported_segments'] ??
        details['imported_laps'] ??
        details['segments'];
    if (rawSegments is List) {
      final segmentLabels = rawSegments
          .whereType<Map>()
          .map((item) => [
                item['type'],
                item['segmentType'],
                item['title'],
                item['name'],
              ].whereType<Object>().join(' ').toLowerCase())
          .toList();
      final hasWork = segmentLabels.any(
        (value) => value.contains('work') || value.contains('interval'),
      );
      final hasRecovery = segmentLabels.any(
        (value) =>
            value.contains('recover') ||
            value.contains('rest') ||
            value.contains('pause'),
      );
      if (hasWork && hasRecovery) return RunningWorkoutMode.intervals;
    }
    return RunningWorkoutMode.free;
  }

  static List<WorkoutPhaseDraft> _emptyRunningPhases() => const [
        WorkoutPhaseDraft(
          type: TrainingPhase.warmup,
          isEnabled: false,
        ),
        WorkoutPhaseDraft(type: TrainingPhase.main),
        WorkoutPhaseDraft(
          type: TrainingPhase.cooldown,
          isEnabled: false,
        ),
      ];

  static RunningSummaryDraft _runningSummaryFromDetails(
    Map<String, dynamic> details, {
    String? source,
  }) {
    final endurance = EnduranceMetrics.fromSessionDetails(details);
    final distanceMeters =
        endurance.distanceKm == null ? null : endurance.distanceKm! * 1000;
    final storedPace = _intValue(details['avg_pace_sec_per_km']) ??
        _parsePaceSeconds(endurance.avgPace);
    return RunningSummaryDraft(
      distanceMeters: distanceMeters,
      avgPaceSecondsPerKm: storedPace,
      avgSpeedKmh: endurance.avgSpeed ?? _speedFromPace(storedPace),
      source: source ??
          (endurance.isImported
              ? RunningMetricSource.imported
              : details['running_metrics_source']?.toString() ??
                  RunningMetricSource.manual),
    );
  }

  static int? _parsePaceSeconds(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+):(\d{1,2})').firstMatch(raw);
    if (match == null) return null;
    return (int.tryParse(match.group(1)!) ?? 0) * 60 +
        (int.tryParse(match.group(2)!) ?? 0);
  }

  static double? _speedFromPace(int? paceSeconds) {
    if (paceSeconds == null || paceSeconds <= 0) return null;
    return double.parse((3600 / paceSeconds).toStringAsFixed(2));
  }

  /// Keeps metadata that is not represented by the unified form while making
  /// its generated workout fields authoritative.
  static TrainingSession preserveOriginalMetadata(
    TrainingSession migrated,
    TrainingSession original,
  ) {
    final originalDetails = Map<String, dynamic>.from(
      original.details ?? const {},
    );
    for (final key in const {
      'schemaVersion',
      'workoutDraft',
      'activityDomain',
      'activityCategory',
      'activityMode',
      'legacyActivityMode',
      'protocolId',
      'protocolName',
      'structureMode',
      'usesPhases',
      'status',
      'workoutSource',
      'title',
      'location',
      'notes',
      'rpe',
      'runningSummary',
      'running_metrics_source',
      'distance',
      'distance_meters',
      'pace',
      'avg_pace_sec_per_km',
      'speed',
      'avg_speed_kmh',
      'plannedDurationMinutes',
      'actualDurationMinutes',
      'plannedStartTime',
      'plannedEndTime',
      'actualStartTime',
      'actualEndTime',
      'participants',
      'externalLink',
      'legacyActivityType',
      'blocks',
      'exercises',
      'prescription',
      'actual',
    }) {
      originalDetails.remove(key);
    }
    originalDetails.addAll(migrated.details ?? const {});
    return TrainingSession(
      id: migrated.id,
      sportId: migrated.sportId,
      date: migrated.date,
      startTime: migrated.startTime,
      endTime: migrated.endTime,
      duration: migrated.duration,
      effort: migrated.effort,
      eventId: original.eventId,
      details: originalDetails,
    );
  }

  static List<WorkoutPhaseDraft> _phasesFromTrainingActivity(
    TrainingActivity activity,
  ) {
    final grouped = <String, List<WorkoutBlockDraft>>{
      TrainingPhase.warmup: [],
      TrainingPhase.main: [],
      TrainingPhase.cooldown: [],
    };
    for (final block in activity.blocks) {
      final phase = TrainingPhase.normalize(block.metrics['phase']);
      final converted = _draftBlocksFromTrainingBlock(block);
      for (final item in converted) {
        grouped[phase]!.add(item.copyWith(order: grouped[phase]!.length));
      }
    }
    return TrainingPhase.ordered
        .map(
          (phase) => WorkoutPhaseDraft(
            type: phase,
            isEnabled:
                phase == TrainingPhase.main || grouped[phase]!.isNotEmpty,
            blocks: grouped[phase]!,
          ),
        )
        .toList();
  }

  static List<WorkoutBlockDraft> _draftBlocksFromTrainingBlock(
    TrainingBlock block,
  ) {
    final converted = <WorkoutBlockDraft>[];
    for (final exercise in block.exercises) {
      converted.add(WorkoutBlockDraft(
        id: exercise.exerciseId.isEmpty
            ? '${block.id}_exercise_${converted.length}'
            : '${block.id}_${exercise.exerciseId}_${converted.length}',
        kind: WorkoutBlockKind.exerciseSets,
        title: exercise.name.isEmpty ? block.name : exercise.name,
        order: converted.length,
        fields: {
          'exerciseId': exercise.exerciseId,
          'equipment': exercise.equipment,
          'variant': exercise.variant,
          'side': exercise.unilateralMode,
          'sets': exercise.sets.map((set) => set.toJson()).toList(),
          if (block.notes != null) 'notes': block.notes,
        }..removeWhere((_, value) => value == null),
      ));
    }
    for (final drill in block.drills) {
      final trials = drill.trials.isNotEmpty
          ? drill.trials
          : List.generate(
              drill.sets ?? 1,
              (index) => SpeedAgilityTrial(
                trialNumber: index + 1,
                distanceM: drill.distanceM,
                timeSeconds: drill.timeSeconds,
                restSeconds: drill.restSeconds,
                startType: drill.startType,
              ),
            );
      converted.add(WorkoutBlockDraft(
        id: '${block.id}_drill_${converted.length}',
        kind: WorkoutBlockKind.exerciseSets,
        title: drill.name.isEmpty ? block.name : drill.name,
        order: converted.length,
        fields: {
          'activityCategory': ActivityCategory.speedAgility,
          'trackingMode': ActivityCategory.speedAgility,
          'speedGroup': drill.type,
          'surface': drill.surface,
          'equipment': drill.equipment.join(', '),
          'sets': trials
              .map(
                (trial) => {
                  'setNumber': trial.trialNumber,
                  'distanceMeters': trial.distanceM,
                  'timeSeconds': trial.timeSeconds,
                  'restSeconds': trial.restSeconds,
                  'intensityPercent': trial.intensityPercent,
                  'startType': trial.startType,
                  'side': trial.side,
                  'notes': trial.notes,
                }..removeWhere((_, value) => value == null),
              )
              .toList(),
          'notes': drill.notes,
        }..removeWhere((_, value) => value == null),
      ));
    }
    for (final entry in block.plyometrics) {
      converted.add(WorkoutBlockDraft(
        id: '${block.id}_plyometric_${converted.length}',
        kind: WorkoutBlockKind.exerciseSets,
        title: entry.exerciseName.isEmpty ? block.name : entry.exerciseName,
        order: converted.length,
        fields: {
          'plyometricType': entry.type,
          'side': entry.unilateralMode,
          'sets': entry.sets.map((set) => set.toJson()).toList(),
          'notes': entry.notes,
        }..removeWhere((_, value) => value == null),
      ));
    }
    final endurance = block.endurance;
    if (endurance != null) {
      converted.add(WorkoutBlockDraft(
        id: '${block.id}_endurance_${converted.length}',
        kind: WorkoutBlockKind.sport,
        title: block.name,
        order: converted.length,
        fields: {
          'durationSeconds': endurance.durationSeconds,
          if (endurance.distanceKm != null)
            'distanceMeters': endurance.distanceKm! * 1000,
          'targetPace': endurance.avgPace ?? endurance.avgSpeed,
          'elevationMeters': endurance.elevationGainM,
          'surface': endurance.surface,
          'avgHeartRate': endurance.avgHr,
          'maxHeartRate': endurance.maxHr,
          'calories': endurance.calories,
          'notes': endurance.notes ?? block.notes,
        }..removeWhere((_, value) => value == null),
      ));
    }
    if (converted.isNotEmpty) return converted;

    final storedKind = block.metrics['blockKind']?.toString();
    final kind = WorkoutBlockKind.values.contains(storedKind)
        ? storedKind!
        : switch (block.type) {
            TrainingBlockType.strength => WorkoutBlockKind.exerciseSets,
            TrainingBlockType.endurance => WorkoutBlockKind.sport,
            TrainingBlockType.circuit => WorkoutBlockKind.circuit,
            _ => WorkoutBlockKind.note,
          };
    final fields = Map<String, dynamic>.from(block.metrics)
      ..remove('phase')
      ..remove('blockKind')
      ..remove('order')
      ..remove('isCompleted');
    if (block.notes != null) fields['notes'] = block.notes;
    return [
      WorkoutBlockDraft(
        id: block.id,
        kind: kind,
        title: block.name,
        order: 0,
        fields: fields,
      ),
    ];
  }

  static ExternalWorkoutLinkDraft? _externalLinkFromDetails(
    TrainingSession session,
    Map<String, dynamic> details,
  ) {
    if (details['externalLink'] is Map) {
      return ExternalWorkoutLinkDraft.fromJson(
        _stringMap(details['externalLink']),
      );
    }
    final externalId = details['external_id']?.toString();
    if (externalId == null || externalId.isEmpty) return null;
    return ExternalWorkoutLinkDraft(
      provider: details['source_name']?.toString() ?? 'health',
      externalActivityId: externalId,
      sourceSessionId: session.id,
      metadata: {'sportId': session.sportId, 'date': session.date},
    );
  }

  static int _sessionDurationMinutes(TrainingSession session) {
    final parsed = int.tryParse(session.duration.trim());
    if (parsed != null && parsed > 0) return parsed;
    final duration = _minutesBetweenClockValues(
      session.startTime,
      session.endTime,
    );
    return duration > 0 ? duration : 60;
  }

  static WorkoutBlockDraft _initialBlock(
    WorkoutActivityDefinition activity,
    WorkoutModeDefinition? mode,
    WorkoutProtocolDefinition? protocol, {
    required int durationMinutes,
  }) {
    final id = 'main_${DateTime.now().microsecondsSinceEpoch}';
    if (protocol != null) {
      return WorkoutBlockDraft(
        id: id,
        kind: WorkoutBlockKind.interval,
        title: protocol.name,
        order: 0,
        fields: Map<String, dynamic>.from(protocol.defaults),
      );
    }
    if (activity.category == ActivityCategory.speedAgility) {
      final suggestedName = activity.suggestedExercises.firstOrNull;
      final exercise = _findCatalogExercise(suggestedName) ??
          exerciseDatabase.firstWhere(
            (item) => item.usesSpeedAgilityTracking,
          );
      return WorkoutBlockDraft(
        id: id,
        kind: WorkoutBlockKind.exerciseSets,
        title: exercise.name,
        order: 0,
        fields: {
          'exerciseId': exercise.id,
          'activityCategory': ActivityCategory.speedAgility,
          'trackingMode': ActivityCategory.speedAgility,
          'speedGroup': exercise.speedGroup,
          'equipmentCategory': exercise.category,
          'sets': List.generate(
            exercise.defaultTrials ?? 4,
            (index) => {
              'setNumber': index + 1,
              'distanceMeters': exercise.defaultDistanceMeters,
              'timeSeconds': null,
              'restSeconds': exercise.defaultRestSeconds,
              'intensityPercent': null,
              'startType': null,
              'side': TrainingSide.none,
            },
          ),
        },
      );
    }
    if (activity.editorKind == WorkoutEditorKind.strength) {
      final suggestedName = activity.suggestedExercises.firstOrNull;
      final exercise = _findCatalogExercise(suggestedName);
      return WorkoutBlockDraft(
        id: id,
        kind: WorkoutBlockKind.exerciseSets,
        title: exercise?.name ?? suggestedName ?? 'Esercizio',
        order: 0,
        fields: {
          if (exercise != null) 'exerciseId': exercise.id,
          'sets': List.generate(
            3,
            (index) => {
              'setNumber': index + 1,
              'kg': null,
              'reps': 8,
              'rpe': null,
              'rir': null,
              'restSeconds': 120,
              'side': TrainingSide.none,
            },
          ),
          'recoverySeconds': 120,
        },
      );
    }
    if (activity.editorKind == WorkoutEditorKind.circuit) {
      return _conditioningBlock(
        id: id,
        modeId: mode?.id ?? 'timed_circuit',
        durationMinutes: durationMinutes,
      );
    }
    return WorkoutBlockDraft(
      id: id,
      kind: WorkoutBlockKind.sport,
      title: activity.name,
      order: 0,
      fields: const {'durationSeconds': 3600},
    );
  }

  static WorkoutBlockDraft _timedPhaseBlock(String phase, int minutes) {
    return WorkoutBlockDraft(
      id: '${phase}_${DateTime.now().microsecondsSinceEpoch}',
      kind: WorkoutBlockKind.timed,
      title: TrainingPhase.label(phase),
      order: 0,
      fields: {'durationSeconds': minutes * 60},
    );
  }

  static WorkoutBlockDraft _conditioningBlock({
    required String id,
    required String modeId,
    required int durationMinutes,
    List<WorkoutBlockDraft> children = const [],
  }) {
    final totalSeconds = durationMinutes * 60;
    return switch (modeId) {
      'work_rest' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.interval,
          title: 'Intervalli lavoro / recupero',
          order: 0,
          fields: {
            'rounds': (totalSeconds / 60).floor().clamp(1, 60),
            'workSeconds': 30,
            'recoverySeconds': 30,
            'timeLimitSeconds': totalSeconds,
          },
          children: children,
        ),
      'tabata' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.interval,
          title: 'Tabata',
          order: 0,
          fields: {
            'rounds': 8,
            'series': (totalSeconds / 240).ceil().clamp(1, 15),
            'workSeconds': 20,
            'recoverySeconds': 10,
            'timeLimitSeconds': totalSeconds,
          },
          children: children,
        ),
      'emom' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'EMOM',
          order: 0,
          fields: {
            'rounds': durationMinutes.clamp(1, 60),
            'timeLimitSeconds': totalSeconds,
            'workSeconds': 45,
            'stationRecoverySeconds': 15,
          },
          children: children,
        ),
      'amrap' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'AMRAP',
          order: 0,
          fields: {'timeLimitSeconds': totalSeconds},
          children: children,
        ),
      'for_time' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'For Time',
          order: 0,
          fields: {'timeLimitSeconds': totalSeconds},
          children: children,
        ),
      'reps_circuit' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'Circuito a ripetizioni',
          order: 0,
          fields: {
            'rounds': 4,
            'repsPerExercise': 10,
            'recoverySeconds': 60,
            'timeLimitSeconds': totalSeconds,
          },
          children: children,
        ),
      'custom' => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'Circuito personalizzato',
          order: 0,
          fields: {'timeLimitSeconds': totalSeconds},
          children: children,
        ),
      _ => WorkoutBlockDraft(
          id: id,
          kind: WorkoutBlockKind.circuit,
          title: 'Circuito a tempo',
          order: 0,
          fields: {
            'rounds': 4,
            'timeLimitSeconds': totalSeconds,
            'workSeconds': 40,
            'stationRecoverySeconds': 20,
            'recoverySeconds': 60,
          },
          children: children,
        ),
    };
  }

  static WorkoutDraft configureConditioningMode(
    WorkoutDraft draft,
    String modeId,
  ) {
    final mainMinutes = conditioningMainMinutes(draft);
    final phases = draft.phases.map((phase) {
      if (phase.type != TrainingPhase.main) return phase;
      final current = phase.blocks.firstOrNull;
      final block = _conditioningBlock(
        id: current?.id ?? 'main_${DateTime.now().microsecondsSinceEpoch}',
        modeId: modeId,
        durationMinutes: mainMinutes,
        children: current?.children ?? const [],
      );
      return phase.copyWith(
        blocks: [block, ...phase.blocks.skip(1)],
      );
    }).toList();
    return draft.copyWith(activityMode: modeId, phases: phases);
  }

  static WorkoutDraft setConditioningDuration(
    WorkoutDraft draft,
    int durationMinutes,
  ) {
    final normalizedDuration = durationMinutes.clamp(10, 60).toInt();
    final endTime = _clockAfterValue(
      draft.effectiveStartTime,
      normalizedDuration,
    );
    var updated = draft.isPlanned
        ? draft.copyWith(
            plannedEndTime: endTime,
            plannedDurationMinutes: normalizedDuration,
          )
        : draft.copyWith(
            actualEndTime: endTime,
            actualDurationMinutes: normalizedDuration,
          );
    updated = _syncConditioningMainDuration(updated);
    return updated;
  }

  static WorkoutDraft syncConditioningPhases(WorkoutDraft draft) =>
      _syncConditioningMainDuration(draft);

  static int conditioningMainMinutes(WorkoutDraft draft) {
    final reservedSeconds = draft.structureMode == WorkoutStructureMode.phased
        ? draft.phases
            .where(
                (phase) => phase.isEnabled && phase.type != TrainingPhase.main)
            .fold<int>(0, (sum, phase) => sum + _phaseDurationSeconds(phase))
        : 0;
    return ((draft.effectiveDurationMinutes * 60 - reservedSeconds) / 60)
        .floor()
        .clamp(1, 60)
        .toInt();
  }

  static WorkoutDraft _syncConditioningMainDuration(WorkoutDraft draft) {
    if (draft.activityId != 'conditioning_hiit') return draft;
    final modeId = draft.activityMode ?? 'timed_circuit';
    final mainMinutes = conditioningMainMinutes(draft);
    final phases = draft.phases.map((phase) {
      if (phase.type != TrainingPhase.main || phase.blocks.isEmpty) {
        return phase;
      }
      final current = phase.blocks.first;
      final configured = _resizeConditioningBlock(
        current,
        modeId: modeId,
        durationMinutes: mainMinutes,
      );
      return phase.copyWith(
        blocks: [configured, ...phase.blocks.skip(1)],
      );
    }).toList();
    return draft.copyWith(phases: phases);
  }

  static WorkoutBlockDraft _resizeConditioningBlock(
    WorkoutBlockDraft block, {
    required String modeId,
    required int durationMinutes,
  }) {
    final fields = Map<String, dynamic>.from(block.fields);
    final totalSeconds = durationMinutes * 60;
    switch (modeId) {
      case 'work_rest':
        final work = (fields['workSeconds'] as num?)?.round() ?? 30;
        final recovery = (fields['recoverySeconds'] as num?)?.round() ?? 30;
        fields['rounds'] =
            (totalSeconds / (work + recovery).clamp(1, totalSeconds))
                .floor()
                .clamp(1, 60);
        fields['timeLimitSeconds'] = totalSeconds;
        break;
      case 'tabata':
        fields['series'] = (totalSeconds / 240).ceil().clamp(1, 15);
        fields['timeLimitSeconds'] = totalSeconds;
        break;
      case 'emom':
        fields['rounds'] = durationMinutes.clamp(1, 60);
        fields['timeLimitSeconds'] = totalSeconds;
        break;
      case 'timed_circuit' ||
            'reps_circuit' ||
            'amrap' ||
            'for_time' ||
            'custom':
        fields['timeLimitSeconds'] = totalSeconds;
        break;
    }
    return block.copyWith(fields: fields);
  }

  static int _phaseDurationSeconds(WorkoutPhaseDraft phase) {
    return phase.blocks.fold<int>(0, (sum, block) {
      final duration = block.fields['durationSeconds'];
      if (duration is num) return sum + duration.round();
      final limit = block.fields['timeLimitSeconds'];
      if (limit is num) return sum + limit.round();
      return sum;
    });
  }
}

class WorkoutImportConflict {
  final String field;
  final Object? manualValue;
  final Object? importedValue;

  const WorkoutImportConflict({
    required this.field,
    required this.manualValue,
    required this.importedValue,
  });
}

class WorkoutExternalMergeService {
  static List<TrainingSession> compatibleImports(
    WorkoutDraft draft,
    Iterable<TrainingSession> sessions,
  ) {
    final candidates = sessions.where((session) {
      if (session.details?['source'] != 'health_sync') return false;
      final date = DateTime.tryParse(session.date);
      if (date == null || !_sameDay(date, draft.date)) return false;
      final draftFamily = HealthWorkoutMergeUtils.sportFamily(draft.activityId);
      final importFamily = HealthWorkoutMergeUtils.sportFamily(session.sportId);
      if (draftFamily != importFamily) return false;
      return _startDeltaMinutes(draft.plannedStartTime, session.startTime) <=
          90;
    }).toList();
    candidates.sort(
      (a, b) => _startDeltaMinutes(draft.plannedStartTime, a.startTime)
          .compareTo(_startDeltaMinutes(draft.plannedStartTime, b.startTime)),
    );
    return candidates;
  }

  static List<WorkoutImportConflict> conflicts(
    WorkoutDraft draft,
    TrainingSession imported,
  ) {
    final conflicts = <WorkoutImportConflict>[];
    final importedDuration = int.tryParse(imported.duration);
    if (importedDuration != null &&
        importedDuration != draft.effectiveDurationMinutes) {
      conflicts.add(WorkoutImportConflict(
        field: 'duration',
        manualValue: draft.effectiveDurationMinutes,
        importedValue: importedDuration,
      ));
    }
    if (imported.startTime != draft.plannedStartTime) {
      conflicts.add(WorkoutImportConflict(
        field: 'startTime',
        manualValue: draft.plannedStartTime,
        importedValue: imported.startTime,
      ));
    }
    return conflicts;
  }

  static TrainingSession merge(
    WorkoutDraft draft,
    TrainingSession imported, {
    bool preferImportedTiming = true,
    String? targetSessionId,
  }) {
    final externalId =
        imported.details?['external_id']?.toString() ?? imported.id;
    final provider = imported.details?['source_name']?.toString() ?? 'health';
    final linkedDraft = draft.copyWith(
      source: WorkoutDataSource.merged,
      externalLink: ExternalWorkoutLinkDraft(
        provider: provider,
        externalActivityId: externalId,
        sourceSessionId: imported.id,
        importedAt: DateTime.now(),
        metadata: {
          'sportId': imported.sportId,
          'date': imported.date,
        },
      ),
      actualDurationMinutes: preferImportedTiming
          ? int.tryParse(imported.duration)
          : draft.actualDurationMinutes,
      actualStartTime:
          preferImportedTiming ? imported.startTime : draft.actualStartTime,
      actualEndTime:
          preferImportedTiming ? imported.endTime : draft.actualEndTime,
    );
    var manual = linkedDraft.toTrainingSession(
      sessionId: targetSessionId ?? imported.id,
    );
    if (!preferImportedTiming) {
      manual = TrainingSession(
        id: manual.id,
        sportId: manual.sportId,
        date: manual.date,
        startTime: manual.startTime,
        endTime: manual.endTime,
        duration: manual.duration,
        effort: manual.effort,
        eventId: manual.eventId,
        details: {
          ...?manual.details,
          'duration_user_overridden': true,
        },
      );
    }
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      manual,
      imported,
    );
    final details = Map<String, dynamic>.from(merged.details ?? {});
    details['workoutSource'] = WorkoutDataSource.merged;
    details['externalLink'] = linkedDraft.externalLink!.toJson();
    details['workoutDraft'] = linkedDraft.toJson();
    return TrainingSession(
      id: merged.id,
      sportId: draft.activityId,
      date: merged.date,
      startTime: merged.startTime,
      endTime: merged.endTime,
      duration: merged.duration,
      effort: merged.effort,
      eventId: merged.eventId,
      details: details,
    );
  }

  static TrainingSession updateLinkedWorkout(
    WorkoutDraft draft,
    TrainingSession existing,
  ) {
    final manual = draft.toTrainingSession(sessionId: existing.id);
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      manual,
      existing,
    );
    final details = Map<String, dynamic>.from(merged.details ?? {});
    details.addAll(manual.details ?? const {});
    return TrainingSession(
      id: existing.id,
      sportId: draft.activityId,
      date: merged.date,
      startTime: merged.startTime,
      endTime: merged.endTime,
      duration: merged.duration,
      effort: manual.effort,
      eventId: existing.eventId,
      details: details,
    );
  }

  static TrainingSession unlink(TrainingSession session) {
    return HealthWorkoutMergeUtils.unlinkImportedData(session);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _startDeltaMinutes(String a, String b) {
    int value(String clock) {
      final parts = clock.split(':');
      if (parts.length < 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    return (value(a) - value(b)).abs();
  }
}

String _clockAfter(DateTime timestamp, int minutes) {
  final value = timestamp.add(Duration(minutes: minutes));
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _clockAfterValue(String clock, int minutes) {
  final parts = clock.split(':');
  final startMinutes = (int.tryParse(parts.first) ?? 0) * 60 +
      (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  final value = (startMinutes + minutes) % (24 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

int _minutesBetweenClockValues(String start, String end) {
  int value(String clock) {
    final parts = clock.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  final startMinutes = value(start);
  final endMinutes = value(end);
  if (startMinutes == endMinutes) return 0;
  return endMinutes > startMinutes
      ? endMinutes - startMinutes
      : (24 * 60 - startMinutes) + endMinutes;
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return {};
  return value.map((key, child) => MapEntry(key.toString(), child));
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_stringMap).toList();
}

int? _intValue(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

ExerciseDef? _findCatalogExercise(String? suggestion) {
  final query = suggestion?.trim().toLowerCase();
  if (query == null || query.isEmpty) return null;
  for (final exercise in exerciseDatabase) {
    final name = exercise.name.toLowerCase();
    if (name == query || name.contains(query) || query.contains(name)) {
      return exercise;
    }
  }
  return null;
}

class LegacyWorkoutMapping {
  final String activityId;
  final String category;
  final String? legacyActivityType;

  const LegacyWorkoutMapping({
    required this.activityId,
    required this.category,
    this.legacyActivityType,
  });
}

class WorkoutLegacyMapper {
  static LegacyWorkoutMapping map({
    required String legacyType,
    String? associatedSportId,
  }) {
    final value = legacyType.toLowerCase().trim();
    if (value.contains('forza')) {
      return const LegacyWorkoutMapping(
        activityId: 'dryland_strength',
        category: ActivityCategory.strength,
      );
    }
    if (value.contains('pliometr')) {
      return const LegacyWorkoutMapping(
        activityId: 'dryland_plyometrics',
        category: ActivityCategory.plyometrics,
      );
    }
    if (value.contains('veloc') || value.contains('agilit')) {
      return const LegacyWorkoutMapping(
        activityId: 'dryland_speed_agility',
        category: ActivityCategory.speedAgility,
      );
    }
    if (value.contains('mobil') || value.contains('core')) {
      return const LegacyWorkoutMapping(
        activityId: 'mobility_recovery',
        category: ActivityCategory.mobility,
      );
    }
    if (value.contains('misto') || value.contains('circuit')) {
      return const LegacyWorkoutMapping(
        activityId: 'conditioning_hiit',
        category: ActivityCategory.circuit,
      );
    }
    if (value.contains('resistenza')) {
      if (associatedSportId != null && associatedSportId.isNotEmpty) {
        return LegacyWorkoutMapping(
          activityId: associatedSportId,
          category: ActivityCategory.sport,
          legacyActivityType: legacyType,
        );
      }
      return LegacyWorkoutMapping(
        activityId: 'other',
        category: ActivityCategory.other,
        legacyActivityType: legacyType,
      );
    }
    return LegacyWorkoutMapping(
      activityId: 'other',
      category: ActivityCategory.other,
      legacyActivityType: legacyType,
    );
  }
}
