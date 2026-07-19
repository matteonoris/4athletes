import 'dart:convert';

import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/services/training_activity_service.dart';
import 'package:flutter_mobile/services/workout_draft_service.dart';
import 'package:flutter_mobile/utils/health_workout_merge_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WorkoutBlockDraft exerciseBlock(String id, String name) {
    return WorkoutBlockDraft(
      id: id,
      kind: WorkoutBlockKind.exerciseSets,
      title: name,
      order: 0,
      fields: const {
        'sets': 3,
        'reps': 5,
        'loadKg': 100,
        'rpe': 8,
        'recoverySeconds': 120,
      },
    );
  }

  WorkoutDraft draft({
    String status = ActivityStatus.completed,
    String structureMode = WorkoutStructureMode.simple,
    List<WorkoutPhaseDraft>? phases,
    List<WorkoutParticipant> participants = const [],
  }) {
    return WorkoutDraft(
      id: 'draft_1',
      createdByUserId: 'user_1',
      creatorRole: status == ActivityStatus.planned ? 'coach' : 'athlete',
      athleteOwnerId: status == ActivityStatus.planned ? null : 'user_1',
      teamId: status == ActivityStatus.planned ? 'team_1' : null,
      title: 'Sessione test',
      date: DateTime(2026, 7, 14),
      plannedStartTime: '09:00',
      actualStartTime: status == ActivityStatus.completed ? '09:03' : null,
      plannedDurationMinutes: status == ActivityStatus.planned ? 60 : null,
      actualDurationMinutes: status == ActivityStatus.completed ? 64 : null,
      activityId: 'dryland_strength',
      activityName: 'Forza',
      activityCategory: ActivityCategory.strength,
      editorKind: WorkoutEditorKind.strength,
      status: status,
      structureMode: structureMode,
      phases: phases ??
          [
            WorkoutPhaseDraft(
              type: TrainingPhase.main,
              blocks: [exerciseBlock('squat_1', 'Squat')],
            ),
          ],
      participants: participants,
      updatedAt: DateTime(2026, 7, 14),
    );
  }

  test('atleta crea allenamento completato semplice con dati effettivi', () {
    final session = draft().toTrainingSession();

    expect(session.details?['status'], ActivityStatus.completed);
    expect(session.details?['actual'], isA<Map>());
    expect(session.details?['prescription'], isNull);
    expect(session.details?['structureMode'], WorkoutStructureMode.simple);
    expect(session.details?['actualDurationMinutes'], 64);
  });

  test('ora di fine determina la durata senza campo minuti separato', () {
    final workout = draft().copyWith(
      actualStartTime: '23:30',
      actualEndTime: '00:45',
      actualDurationMinutes: 10,
    );
    final session = workout.toTrainingSession();

    expect(workout.effectiveDurationMinutes, 75);
    expect(session.startTime, '23:30');
    expect(session.endTime, '00:45');
    expect(session.duration, '75');
  });

  test('RPE complessivo viene salvato nel draft e nella sessione', () {
    final workout = draft().copyWith(sessionRpe: 9);
    final restored = WorkoutDraft.fromJson(workout.toJson());
    final session = restored.toTrainingSession();

    expect(restored.sessionRpe, 9);
    expect(session.effort, 9);
    expect(session.details?['rpe'], 9);
    expect(
      (session.details?['workoutDraft'] as Map)['sessionRpe'],
      9,
    );
  });

  test('sessione weightlifting legacy viene convertita senza perdere le serie',
      () {
    final legacy = TrainingSession(
      id: 'legacy_weightlifting',
      sportId: 'weightlifting',
      date: '2026-07-14',
      startTime: '09:40',
      endTime: '10:20',
      duration: '40',
      effort: 6,
      details: const {
        'location': 'Palestra',
        'painZones': ['Schiena'],
        'exercises': [
          {
            'id': 'snatch',
            'name': 'Snatch',
            'sets': [
              {'kg': 45, 'reps': 3},
              {'kg': 50, 'reps': 2},
            ],
          },
        ],
      },
    );
    final activity = WorkoutCatalog.editableDefinition(legacy.sportId);
    final converted = WorkoutDraftFactory.fromTrainingSession(
      session: legacy,
      activity: activity,
      userId: 'athlete_1',
    );

    final main = converted.phases.singleWhere(
      (phase) => phase.type == TrainingPhase.main,
    );
    final sets = main.blocks.single.fields['sets'] as List;
    expect(converted.activityId, 'weightlifting');
    expect(converted.title, 'Weightlifting');
    expect(converted.location, 'Palestra');
    expect(main.blocks.single.title, 'Snatch');
    expect((sets.first as Map)['kg'], 45);
    expect((sets.last as Map)['reps'], 2);

    final migrated = WorkoutDraftFactory.preserveOriginalMetadata(
      converted.toTrainingSession(sessionId: legacy.id),
      legacy,
    );
    expect(migrated.details?['painZones'], ['Schiena']);
    expect(migrated.details?['schemaVersion'], WorkoutDraft.schemaVersion);
    expect(migrated.details?['exercises'], isNull);
  });

  test('sport legacy non catalogato conserva id e nome nel nuovo editor', () {
    final activity = WorkoutCatalog.editableDefinition(
      'pickleball',
      displayName: 'Pickleball',
    );

    expect(activity.id, 'pickleball');
    expect(activity.name, 'Pickleball');
    expect(activity.editorKind, WorkoutEditorKind.universal);
  });

  test('ogni serie conserva peso e ripetizioni indipendenti', () {
    final workout = draft(phases: const [
      WorkoutPhaseDraft(
        type: TrainingPhase.main,
        blocks: [
          WorkoutBlockDraft(
            id: 'bench_press',
            kind: WorkoutBlockKind.exerciseSets,
            title: 'Barbell Bench Press',
            order: 0,
            fields: {
              'exerciseId': 'bench_press',
              'sets': [
                {'setNumber': 1, 'kg': 80, 'reps': 8},
                {'setNumber': 2, 'kg': 85, 'reps': 6},
                {'setNumber': 3, 'kg': 90, 'reps': 4},
              ],
            },
          ),
        ],
      ),
    ]);
    final session = workout.toTrainingSession();
    final blocks = session.details?['blocks'] as List;
    final exercises = (blocks.single as Map)['exercises'] as List;
    final sets = (exercises.single as Map)['sets'] as List;

    expect((exercises.single as Map)['exerciseId'], 'bench_press');
    expect(sets, hasLength(3));
    expect((sets[0] as Map)['kg'], 80);
    expect((sets[1] as Map)['reps'], 6);
    expect((sets[2] as Map)['kg'], 90);
  });

  test('drill velocita conserva prove e non viene salvato come forza', () {
    final workout = draft().copyWith(
      activityId: 'dryland_speed_agility',
      activityName: 'Velocita e agilita',
      activityCategory: ActivityCategory.speedAgility,
      editorKind: WorkoutEditorKind.universal,
      phases: const [
        WorkoutPhaseDraft(
          type: TrainingPhase.main,
          blocks: [
            WorkoutBlockDraft(
              id: 'flying_20',
              kind: WorkoutBlockKind.exerciseSets,
              title: 'Flying Sprint 20 m',
              order: 0,
              fields: {
                'exerciseId': 'speed_flying_20',
                'activityCategory': ActivityCategory.speedAgility,
                'trackingMode': ActivityCategory.speedAgility,
                'speedGroup': 'Velocita massima',
                'sets': [
                  {
                    'setNumber': 1,
                    'distanceMeters': 20,
                    'timeSeconds': 2.11,
                    'restSeconds': 240,
                  },
                  {
                    'setNumber': 2,
                    'distanceMeters': 20,
                    'timeSeconds': 2.05,
                    'restSeconds': 240,
                  },
                ],
              },
            ),
          ],
        ),
      ],
    );

    final session = workout.toTrainingSession();
    final block = (session.details?['blocks'] as List).single as Map;
    final restored = TrainingActivity.fromTrainingSession(session);
    final drill = restored.blocks.single.drills.single;

    expect(block['type'], TrainingBlockType.speedAgility);
    expect(block['exercises'], isEmpty);
    expect(block['drills'], hasLength(1));
    expect(drill.trials, hasLength(2));
    expect(drill.totalDistanceM, 40);
    expect(drill.bestTimeSeconds, 2.05);
  });

  test('scheda completa mantiene riscaldamento, main e defaticamento', () {
    final workout = draft(
      structureMode: WorkoutStructureMode.phased,
      phases: [
        WorkoutPhaseDraft(
          type: TrainingPhase.warmup,
          blocks: [exerciseBlock('warm_squat', 'Goblet squat')],
        ),
        WorkoutPhaseDraft(
          type: TrainingPhase.main,
          blocks: [exerciseBlock('main_squat', 'Back squat')],
        ),
        const WorkoutPhaseDraft(
          type: TrainingPhase.cooldown,
          blocks: [
            WorkoutBlockDraft(
              id: 'cool_generic',
              kind: WorkoutBlockKind.exercise,
              title: 'Respirazione con carico leggero',
              order: 0,
              fields: {'durationSeconds': 180},
            ),
          ],
        ),
      ],
    );

    final session = workout.toTrainingSession();
    final blocks = session.details?['blocks'] as List;
    expect(blocks, hasLength(3));
    expect((blocks.first as Map)['metrics']['phase'], TrainingPhase.warmup);
    expect((blocks.last as Map)['metrics']['phase'], TrainingPhase.cooldown);
  });

  test('coach pianifica per team con piu atleti e stati partecipante', () {
    final workout = draft(
      status: ActivityStatus.planned,
      participants: const [
        WorkoutParticipant(athleteId: 'athlete_1', name: 'Anna'),
        WorkoutParticipant(
          athleteId: 'athlete_2',
          name: 'Luca',
          invitationStatus: WorkoutInvitationStatus.confirmed,
        ),
      ],
    );
    final session = workout.toTrainingSession();

    expect(session.details?['prescription'], isA<Map>());
    expect(session.details?['actual'], isNull);
    expect(session.details?['participants'], hasLength(2));
    expect(
      (session.details?['participants'] as List).last['invitationStatus'],
      WorkoutInvitationStatus.confirmed,
    );
  });

  test('coach puo creare anche un allenamento completato', () {
    final workout = draft().copyWith(creatorRole: 'coach');
    expect(workout.toTrainingSession().details?['actual'], isA<Map>());
  });

  test('prescrizione e dati effettivi rimangono payload separati', () {
    final planned = draft(status: ActivityStatus.planned).toTrainingSession();
    final details = Map<String, dynamic>.from(planned.details!);
    details['actual'] = {
      'durationMinutes': 64,
      'phases': [
        {
          'type': TrainingPhase.main,
          'blocks': [
            {'id': 'actual', 'kind': 'exercise', 'title': 'Squat', 'order': 0}
          ]
        }
      ]
    };

    expect((details['prescription'] as Map)['durationMinutes'], 60);
    expect((details['actual'] as Map)['durationMinutes'], 64);
    expect(details['prescription'], isNot(same(details['actual'])));
  });

  test('Forza Powerlifting e Weightlifting condividono lo stesso editor', () {
    expect(
      WorkoutCatalog.byId('dryland_strength').editorKind,
      WorkoutEditorKind.strength,
    );
    expect(
      WorkoutCatalog.byId('powerlifting').editorKind,
      WorkoutEditorKind.strength,
    );
    expect(
      WorkoutCatalog.byId('weightlifting').editorKind,
      WorkoutEditorKind.strength,
    );
  });

  test('i nomi dryland sono presentati senza cambiare gli ID stabili', () {
    const expectedNames = {
      'dryland_strength': 'Forza',
      'dryland_plyometrics': 'Pliometria',
      'dryland_speed_agility': 'Velocità e agilità',
    };

    for (final entry in expectedNames.entries) {
      final activity = WorkoutCatalog.byId(entry.key);
      expect(activity.id, entry.key);
      expect(WorkoutCatalog.displayName(entry.key), entry.value);
    }

    expect(WorkoutCatalog.displayName('Dryland Strength'), 'Forza');
    expect(WorkoutCatalog.displayName('dryland_forza'), 'Forza');
    expect(WorkoutCatalog.stableSportId('Forza'), 'dryland_strength');
    expect(
      WorkoutCatalog.stableSportId('Velocità e agilità'),
      'dryland_speed_agility',
    );
    expect(
      WorkoutCatalog.stableSportId('dryland_plyometrics'),
      'dryland_plyometrics',
    );
  });

  test('circuito HIIT supporta round, recupero ed esercizi misti', () {
    const circuit = WorkoutBlockDraft(
      id: 'circuit_1',
      kind: WorkoutBlockKind.circuit,
      title: '4 round',
      order: 0,
      fields: {'rounds': 4, 'recoverySeconds': 60},
      children: [
        WorkoutBlockDraft(
          id: 'bike',
          kind: WorkoutBlockKind.timed,
          title: 'Assault Bike',
          order: 0,
          fields: {'durationSeconds': 30},
        ),
        WorkoutBlockDraft(
          id: 'swing',
          kind: WorkoutBlockKind.exercise,
          title: 'Kettlebell swing',
          order: 1,
          fields: {'reps': 10},
        ),
        WorkoutBlockDraft(
          id: 'burpees',
          kind: WorkoutBlockKind.exercise,
          title: 'Burpees',
          order: 2,
          fields: {'reps': 8},
        ),
      ],
    );

    expect(circuit.isValid, isTrue);
    expect(circuit.children, hasLength(3));
    expect(circuit.fields['rounds'], 4);
  });

  test('Conditioning parte da 30 minuti divisi tra le tre fasi', () {
    final workout = WorkoutDraftFactory.create(
      activity: WorkoutCatalog.byId('conditioning_hiit'),
      userId: 'athlete_1',
      creatorRole: 'athlete',
      now: DateTime(2026, 7, 15, 9),
    );

    expect(workout.structureMode, WorkoutStructureMode.phased);
    expect(workout.activityMode, 'timed_circuit');
    expect(workout.effectiveDurationMinutes, 30);
    expect(workout.phases.first.isEnabled, isTrue);
    expect(workout.phases.last.isEnabled, isTrue);
    expect(
      workout.phases.first.blocks.single.fields['durationSeconds'],
      300,
    );
    expect(WorkoutDraftFactory.conditioningMainMinutes(workout), 20);
    expect(
      workout.phases[1].blocks.single.fields['timeLimitSeconds'],
      1200,
    );
  });

  test('durata Conditioning aggiorna fine e lavoro principale', () {
    final workout = WorkoutDraftFactory.create(
      activity: WorkoutCatalog.byId('conditioning_hiit'),
      userId: 'athlete_1',
      creatorRole: 'athlete',
      now: DateTime(2026, 7, 15, 9),
    );
    final resized = WorkoutDraftFactory.setConditioningDuration(workout, 45);

    expect(resized.effectiveEndTime, '09:45');
    expect(resized.effectiveDurationMinutes, 45);
    expect(WorkoutDraftFactory.conditioningMainMinutes(resized), 35);
    expect(
      resized.phases[1].blocks.single.fields['timeLimitSeconds'],
      2100,
    );
  });

  test('modalita intervalli configura round dal tempo disponibile', () {
    final workout = WorkoutDraftFactory.create(
      activity: WorkoutCatalog.byId('conditioning_hiit'),
      userId: 'athlete_1',
      creatorRole: 'athlete',
      now: DateTime(2026, 7, 15, 9),
    );
    final intervals = WorkoutDraftFactory.configureConditioningMode(
      workout,
      'work_rest',
    );
    final main = intervals.phases[1].blocks.single;

    expect(main.kind, WorkoutBlockKind.interval);
    expect(main.fields['workSeconds'], 30);
    expect(main.fields['recoverySeconds'], 30);
    expect(main.fields['rounds'], 20);

    final tabata = WorkoutDraftFactory.configureConditioningMode(
      workout,
      'tabata',
    ).phases[1].blocks.single;
    expect(tabata.fields['series'], 5);
    expect(tabata.fields['timeLimitSeconds'], 1200);

    final repsCircuit = WorkoutDraftFactory.configureConditioningMode(
      workout,
      'reps_circuit',
    ).phases[1].blocks.single;
    expect(repsCircuit.fields['timeLimitSeconds'], 1200);
  });

  test('Norwegian 4x4 appartiene a corsa e intervalli', () {
    final protocol = WorkoutCatalog.protocolById('norwegian_4x4')!;
    expect(protocol.activityId, 'running');
    expect(protocol.modeId, 'intervals');
    expect(protocol.matches('4x4'), isTrue);
  });

  test('sinonimi trovano pesi, ripetute e circuito', () {
    expect(WorkoutCatalog.byId('dryland_strength').matches('pesi'), isTrue);
    expect(WorkoutCatalog.byId('powerlifting').matches('pesi'), isTrue);
    expect(WorkoutCatalog.byId('weightlifting').matches('pesi'), isTrue);
    expect(
      WorkoutCatalog.runningModes
          .firstWhere((mode) => mode.id == 'intervals')
          .matches('ripetute'),
      isTrue,
    );
    expect(
        WorkoutCatalog.byId('conditioning_hiit').matches('circuito'), isTrue);
  });

  test('merge Health conserva blocchi manuali e provenienza', () {
    final workout = draft(status: ActivityStatus.planned).copyWith(
      activityId: 'running',
      activityName: 'Corsa',
      activityCategory: ActivityCategory.sport,
      editorKind: WorkoutEditorKind.endurance,
      activityMode: 'intervals',
      protocolId: 'norwegian_4x4',
      structureMode: WorkoutStructureMode.phased,
      phases: const [
        WorkoutPhaseDraft(
          type: TrainingPhase.main,
          blocks: [
            WorkoutBlockDraft(
              id: 'intervals',
              kind: WorkoutBlockKind.interval,
              title: 'Norwegian 4x4',
              order: 0,
              fields: {
                'workUnit': 'time',
                'repetitions': 4,
                'series': 1,
                'workSeconds': 240,
                'repRecoveryUnit': 'time',
                'repRecoverySeconds': 180,
              },
            ),
          ],
        ),
      ],
    );
    final imported = TrainingSession(
      id: 'health_row_1',
      sportId: 'running',
      date: '2026-07-14',
      startTime: '09:02',
      endTime: '10:06',
      duration: '64',
      effort: 6,
      details: const {
        'source': 'health_sync',
        'source_name': 'Health Connect',
        'external_id': 'external_1',
        'avg_hr': 158,
      },
    );

    final merged = WorkoutExternalMergeService.merge(workout, imported);
    expect(merged.id, imported.id);
    expect(merged.details?['workoutSource'], WorkoutDataSource.merged);
    expect(merged.details?['prescription'], isA<Map>());
    expect(merged.details?['blocks'], isNotEmpty);
    expect(merged.details?['avg_hr'], 158);
    expect(merged.details?['externalLink']['externalActivityId'], 'external_1');
    expect(WorkoutProvenance.isMerged(merged), isTrue);
    expect(WorkoutProvenance.isCoachCreated(merged), isTrue);
  });

  test('sincronizzazione ripetuta riconosce external id senza duplicare', () {
    TrainingSession imported(String id) => TrainingSession(
          id: id,
          sportId: 'running',
          date: '2026-07-14',
          startTime: '09:00',
          endTime: '10:00',
          duration: '60',
          effort: 5,
          details: const {
            'source': 'health_sync',
            'external_id': 'same_external_id',
          },
        );

    final duplicates = HealthWorkoutMergeUtils.likelyDuplicateHealthImports(
      [imported('stored')],
      imported('new'),
    );
    expect(duplicates.single.id, 'stored');
  });

  test('scollegamento rimuove Health e conserva struttura manuale', () {
    final imported = TrainingSession(
      id: 'health_row_1',
      sportId: 'running',
      date: '2026-07-14',
      startTime: '09:00',
      endTime: '10:00',
      duration: '60',
      effort: 5,
      details: const {
        'source': 'health_sync',
        'workoutSource': 'merged',
        'external_id': 'external_1',
        'avg_hr': 150,
        'blocks': [
          {'id': 'manual', 'type': 'strength', 'name': 'Squat'}
        ],
      },
    );

    final unlinked = WorkoutExternalMergeService.unlink(imported);
    expect(unlinked.details?['external_id'], isNull);
    expect(unlinked.details?['avg_hr'], isNull);
    expect(unlinked.details?['source'], 'manual');
    expect(unlinked.details?['blocks'], isNotEmpty);
  });

  test('template v3 salva metadati e viene applicato come copia', () {
    final session = draft().toTrainingSession();
    final activity = TrainingActivity.fromTrainingSession(session);
    final template = const TrainingActivityService().saveActivityAsTemplate(
      activity,
      templateId: 'template_1',
      name: 'Forza completa',
      ownerType: TemplateOwnerType.athlete,
      ownerId: 'user_1',
      createdBy: 'user_1',
      activityMode: 'sets',
      protocolId: 'custom_strength',
      structureMode: WorkoutStructureMode.phased,
      plannedDurationMinutes: 75,
      now: DateTime(2026, 7, 14),
    );
    final restored = WorkoutTemplate.fromJson(template.toJson());
    final generated = restored.instantiateActivity(
      id: 'copy_1',
      athleteId: 'user_1',
      date: '2026-07-15',
      startTime: '10:00',
      endTime: '11:15',
      duration: '75',
    );

    expect(restored.protocolId, 'custom_strength');
    expect(restored.structureMode, WorkoutStructureMode.phased);
    expect(restored.plannedDurationMinutes, 75);
    expect(generated.blocks, isNot(same(restored.blocks)));
  });

  test('mapper legacy conserva Resistenza ambigua senza inventare sport', () {
    final ambiguous = WorkoutLegacyMapper.map(legacyType: 'Resistenza');
    final known = WorkoutLegacyMapper.map(
      legacyType: 'Resistenza',
      associatedSportId: 'cycling',
    );
    final mixed = WorkoutLegacyMapper.map(legacyType: 'Misto / Circuito');

    expect(ambiguous.activityId, 'other');
    expect(ambiguous.legacyActivityType, 'Resistenza');
    expect(known.activityId, 'cycling');
    expect(mixed.activityId, 'conditioning_hiit');
  });

  test('coach crea evento team v4 conservando scheda e partecipanti', () {
    final workout = draft(
      status: ActivityStatus.planned,
      structureMode: WorkoutStructureMode.phased,
      participants: const [
        WorkoutParticipant(athleteId: 'athlete_1', name: 'Mario Rossi'),
      ],
    );
    final event = CoachWorkoutEventFactory.create(
      draft: workout,
      team: Team(
        id: 'team_1',
        name: 'Sci Club',
        members: 1,
        category: 'U18',
        image: '',
        inviteCode: 'ABC123',
      ),
      coachId: 'coach_1',
      eventId: 'event_1',
    );

    expect(event.status, ActivityStatus.planned);
    expect(event.technicalDetails?['technicalVersion'], 4);
    expect(event.technicalDetails?['sessionRpe'], 5);
    expect(event.technicalDetails?['qualityRating'], 5);
    expect(event.technicalDetails?['workoutDraft'], isA<Map>());
    expect(
      (event.technicalDetails?['plannedDrylandSession'] as Map)['blocks'],
      isNotEmpty,
    );
    expect(event.attendees?.single['attendanceStatus'], 'pending');
    expect(event.attendees?.single['completionStatus'], 'pending');
    expect(event.attendees?.single['isPresent'], isNull);

    final preview = CoachWorkoutEventFactory.previewSession(
      event: event,
      draft: workout,
    );
    expect(preview.eventId, 'event_1');
    expect(preview.details?['createdByCoach'], isTrue);
    expect(preview.details?['workoutDraft'], isA<Map>());
  });

  test('evento coach completato marca gli atleti presenti e completati', () {
    final event = CoachWorkoutEventFactory.create(
      draft: draft(
        participants: const [
          WorkoutParticipant(athleteId: 'athlete_1', name: 'Mario Rossi'),
        ],
      ),
      team: Team(
        id: 'team_1',
        name: 'Sci Club',
        members: 1,
        category: 'U18',
        image: '',
        inviteCode: 'ABC123',
      ),
      coachId: 'coach_1',
      eventId: 'event_2',
    );

    expect(event.attendees?.single['attendanceStatus'], 'present');
    expect(event.attendees?.single['completionStatus'], 'completed');
    expect(event.attendees?.single['isPresent'], isTrue);

    final details = const TrainingActivityService()
        .buildCoachDrylandSessionDetails(event, event.attendees!.single);
    expect(details['schemaVersion'], 3);
    expect(details['workoutDraft'], isA<Map>());
    expect(details['prescription'], isA<Map>());
  });

  test('bozza locale viene salvata, ripristinata e rimossa', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = WorkoutDraftStore(prefs);
    final original = draft();

    await store.save('user_1', original);
    expect(store.load('user_1')?.title, original.title);
    await store.clear('user_1');
    expect(store.load('user_1'), isNull);
  });

  test('bozza v4 ripristina anche la precedente chiave locale v3', () async {
    final original = draft();
    SharedPreferences.setMockInitialValues({
      'workout_draft_v3_user_legacy': jsonEncode(original.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = WorkoutDraftStore(prefs);

    expect(store.load('user_legacy')?.title, original.title);
    await store.clear('user_legacy');
    expect(store.load('user_legacy'), isNull);
  });
}
