import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/services/monthly_training_classifier.dart';
import 'package:flutter_mobile/services/workout_draft_service.dart';
import 'package:flutter_mobile/utils/health_workout_merge_utils.dart';
import 'package:flutter_mobile/utils/workout_session_type_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingSession imported({String sportId = 'athletic_prep'}) =>
      TrainingSession(
        id: 'recorded-session',
        sportId: sportId,
        date: '2026-10-05',
        startTime: '10:00',
        endTime: '11:00',
        duration: '60',
        effort: 6,
        details: {
          'source': 'health_sync',
          'external_id': 'provider-workout',
          'source_name': 'Garmin',
          'title': WorkoutCatalog.displayName(sportId),
          'calories': 450,
          'notes': 'Sprint in salita',
        },
      );

  test('reclassifying an import preserves recorded data and updates reports',
      () {
    final original = imported();
    final updated = WorkoutSessionTypeUtils.changeType(
      original,
      WorkoutCatalog.byId('dryland_speed_agility'),
    );
    expect(updated.id, original.id);
    expect(updated.duration, original.duration);
    expect(updated.startTime, original.startTime);
    expect(updated.endTime, original.endTime);
    expect(updated.effort, original.effort);
    expect(updated.details?['external_id'], 'provider-workout');
    expect(updated.details?['source_name'], 'Garmin');
    expect(updated.details?['calories'], 450);
    expect(updated.details?['notes'], 'Sprint in salita');
    expect(updated.details?['title'], 'Velocità e agilità');
    expect(TrainingActivity.fromTrainingSession(updated).category,
        ActivityCategory.speedAgility);
    expect(const MonthlyTrainingClassifier().classify(updated).detailLabel,
        'Velocità e agilità');
    expect(original.sportId, 'athletic_prep');
    expect(original.details?['activity_type_user_overridden'], isNull);
  });

  test('later imports refresh metrics without replacing the selected type', () {
    final selected = WorkoutSessionTypeUtils.changeType(
      imported(),
      WorkoutCatalog.byId('dryland_speed_agility'),
    );
    final refresh = imported();
    refresh.details!.addAll({
      'activityCategory': ActivityCategory.athleticPrep,
      'prepType': DrylandPrepType.mixedCircuit,
      'activityDomain': 'sport',
      'calories': 480,
      'protocolId': 'provider-protocol',
    });
    final merged =
        HealthWorkoutMergeUtils.mergeImportedSession(selected, refresh);
    expect(merged.sportId, 'dryland_speed_agility');
    expect(merged.details?['activityCategory'], ActivityCategory.speedAgility);
    expect(merged.details?['prepType'], DrylandPrepType.speedAgility);
    expect(merged.details?['activityDomain'], 'dryland');
    expect(merged.details?['title'], 'Velocità e agilità');
    expect(merged.details?['protocolId'], isNull);
    expect(merged.details?['calories'], 480);
    expect(merged.details?['external_id'], 'provider-workout');
  });

  test('original import family still matches after selecting a different sport',
      () {
    final selected = WorkoutSessionTypeUtils.changeType(
      imported(sportId: 'running'),
      WorkoutCatalog.byId('dryland_speed_agility'),
    );
    final refresh = imported(sportId: 'running');
    refresh.id = 'incoming-provider-session';
    refresh.details!['external_id'] = 'provider-new-part';
    expect(
        HealthWorkoutMergeUtils.bestOverlapMergeCandidate([selected], refresh),
        same(selected));
    expect(
        HealthWorkoutMergeUtils.likelyDuplicateHealthImports(
            [selected], refresh),
        [selected]);
    final selectedAgain = WorkoutSessionTypeUtils.changeType(
        selected, WorkoutCatalog.byId('dryland_strength'));
    expect(
        selectedAgain.details?['activity_type_original_sport_id'], 'running');
  });

  test('structured workout keeps its custom title and content when reopened',
      () {
    final original = imported();
    original.details!['title'] = 'Seduta del lunedì';
    final draft = WorkoutDraftFactory.fromTrainingSession(
      session: original,
      activity: WorkoutCatalog.byId('conditioning_hiit'),
      userId: 'athlete',
    ).copyWith(
      title: 'Seduta del lunedì',
      activityMode: 'emom',
      protocolId: 'old-protocol',
      phases: const [
        WorkoutPhaseDraft(type: TrainingPhase.main, blocks: [
          WorkoutBlockDraft(
              id: 'sprint',
              kind: WorkoutBlockKind.timed,
              title: 'Sprint 30 m',
              order: 0,
              fields: {'distanceMeters': 30}),
        ])
      ],
    );
    final session = draft.toTrainingSession(sessionId: original.id);
    final updated = WorkoutSessionTypeUtils.changeType(
        session, WorkoutCatalog.byId('dryland_speed_agility'));
    final reloaded = TrainingSession.fromJson(updated.toJson());
    final stored = WorkoutDraft.fromJson(
        reloaded.details!['workoutDraft'] as Map<String, dynamic>);
    expect(stored.activityId, 'dryland_speed_agility');
    expect(stored.activityName, 'Velocità e agilità');
    expect(stored.activityCategory, ActivityCategory.speedAgility);
    expect(stored.editorKind, WorkoutEditorKind.universal);
    expect(stored.title, 'Seduta del lunedì');
    expect(stored.protocolId, isNull);
    expect(stored.phases.single.blocks.single.title, 'Sprint 30 m');
    final refreshed =
        HealthWorkoutMergeUtils.mergeImportedSession(updated, imported());
    expect(
        refreshed.details?['workoutDraft'], updated.details?['workoutDraft']);
    expect(refreshed.details?['blocks'], updated.details?['blocks']);
  });

  test('ski details and coach linkage survive a classification change', () {
    final session = imported(sportId: 'alpine_skiing');
    session.eventId = 'coach-event';
    session.details!['skiSpecialties'] = [
      {
        'specialty': 'SL',
        'tracks': [
          {'laps': 8}
        ]
      },
      {
        'specialty': 'GS',
        'tracks': [
          {'laps': 5}
        ]
      },
    ];
    final updated = WorkoutSessionTypeUtils.changeType(
        session, WorkoutCatalog.byId('running'));
    expect(updated.eventId, 'coach-event');
    expect(
        updated.details?['skiSpecialties'], session.details?['skiSpecialties']);
    expect(updated.details?['prepType'], isNull);
  });
}
