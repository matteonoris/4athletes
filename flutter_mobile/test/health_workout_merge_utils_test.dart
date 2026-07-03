import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/health_workout_merge_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingSession manualStrength({
    String id = 'manual_1',
    String startTime = '18:00:00',
    String endTime = '20:17:00',
  }) {
    return TrainingSession(
      id: id,
      sportId: 'weightlifting',
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '137',
      effort: 7,
      details: const {
        'activityDomain': 'dryland',
        'title': 'Weightlifting',
        'blocks': [
          {
            'type': 'strength',
            'name': 'Forza',
            'exercises': [
              {
                'name': 'Bench Press',
                'sets': [
                  {'kg': 80, 'reps': 5}
                ]
              }
            ]
          }
        ],
      },
    );
  }

  TrainingSession importedWeightlifting({
    String id = 'import_1',
    String startTime = '18:06:00',
    String endTime = '20:35:00',
    String externalId = 'wearable-1',
    String sourceName = 'com.thirdparty.watch',
  }) {
    return TrainingSession(
      id: id,
      sportId: 'weightlifting',
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '137',
      effort: 5,
      details: {
        'source': 'health_sync',
        'external_id': externalId,
        'source_name': sourceName,
        'active_duration_seconds': 8220,
        'avg_hr': 90,
        'max_hr': 133,
        'hr_samples': [
          {'time': 1781280360000, 'bpm': 90}
        ],
      },
    );
  }

  TrainingSession coachDrylandSession({
    String id = 'coach_dryland_1',
    String startTime = '18:00:00',
    String endTime = '19:00:00',
  }) {
    return TrainingSession(
      id: id,
      sportId: 'athletic_prep',
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '60',
      effort: 6,
      eventId: 'coach_event_dryland_1',
      details: const {
        'schemaVersion': 2,
        'activityDomain': 'dryland',
        'activityCategory': 'athletic_prep',
        'source': 'coach',
        'from_calendar': true,
        'createdByCoach': true,
        'title': 'Preparazione atletica',
        'blocks': [
          {
            'type': 'strength',
            'name': 'Circuito',
            'exercises': [
              {
                'name': 'Squat',
                'sets': [
                  {'kg': 60, 'reps': 8}
                ]
              }
            ]
          }
        ],
      },
    );
  }

  TrainingSession coachSkiSession({
    String id = 'coach_ski_1',
    String startTime = '09:00:00',
    String endTime = '12:00:00',
  }) {
    return TrainingSession(
      id: id,
      sportId: 'alpine_skiing',
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '180',
      effort: 7,
      eventId: 'coach_event_1',
      details: const {
        'skiSchemaVersion': 2,
        'activityDomain': 'sport',
        'snowCondition': 'Compatta',
        'gatedSkiing': {'laps': '8'},
      },
    );
  }

  TrainingSession importedSnowSports({
    String id = 'import_snow_1',
    String sportId = 'snow_sports',
    String startTime = '09:07:00',
    String endTime = '12:10:00',
  }) {
    return TrainingSession(
      id: id,
      sportId: sportId,
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '183',
      effort: 5,
      details: const {
        'source': 'health_sync',
        'external_id': 'garmin-snow-1',
        'source_name': 'com.garmin.android.apps.connectmobile',
        'active_duration_seconds': 10980,
        'avg_hr': 132,
        'max_hr': 171,
        'hr_samples': [
          {'time': 1781248020000, 'bpm': 132}
        ],
      },
    );
  }

  test(
      'fonde forza strutturata e import wearable con orari leggermente diversi',
      () {
    final existing = manualStrength();
    final imported = importedWeightlifting();

    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [existing],
      imported,
    );
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      candidate!,
      imported,
    );

    expect(candidate.id, existing.id);
    expect(merged.id, existing.id);
    expect(merged.startTime, '18:06:00');
    expect(merged.endTime, '20:35:00');
    expect(merged.duration, '149');
    expect(merged.effort, 7);
    expect(merged.details?['blocks'], existing.details?['blocks']);
    expect(merged.details?['source'], 'health_sync');
    expect(merged.details?['total_duration_minutes'], 149);
    expect(merged.details?['avg_hr'], 90);
    expect(merged.details?['max_hr'], 133);
  });

  test('fonde per inizio entro dieci minuti anche con sovrapposizione debole',
      () {
    final existing = manualStrength(endTime: '18:20:00');
    final imported = importedWeightlifting(
      startTime: '18:08:00',
      endTime: '20:00:00',
    );

    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [existing],
      imported,
    );
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      candidate!,
      imported,
    );

    expect(candidate.id, existing.id);
    expect(merged.startTime, '18:08:00');
    expect(merged.endTime, '20:00:00');
  });

  test('fonde preparazione coach e import forza con inizio entro dieci minuti',
      () {
    final existing = coachDrylandSession();
    final imported = importedWeightlifting(
      startTime: '18:09:00',
      endTime: '19:20:00',
    );

    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [existing],
      imported,
    );
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      candidate!,
      imported,
    );

    expect(candidate.id, existing.id);
    expect(merged.id, existing.id);
    expect(merged.eventId, existing.eventId);
    expect(merged.startTime, '18:09:00');
    expect(merged.endTime, '19:20:00');
    expect(merged.duration, '71');
    expect(merged.details?['from_calendar'], isTrue);
    expect(merged.details?['createdByCoach'], isTrue);
    expect(merged.details?['blocks'], existing.details?['blocks']);
    expect(merged.details?['source'], 'health_sync');
  });

  test('mantiene la durata manuale modificata dopo un merge health', () {
    final existing = manualStrength(
      startTime: '18:00:00',
      endTime: '19:00:00',
    );
    final imported = importedWeightlifting(
      startTime: '18:05:00',
      endTime: '20:00:00',
    );
    final previouslyMerged = HealthWorkoutMergeUtils.mergeImportedSession(
      existing,
      imported,
    );

    final manuallyShortened = TrainingSession(
      id: previouslyMerged.id,
      sportId: previouslyMerged.sportId,
      date: previouslyMerged.date,
      startTime: '18:00:00',
      endTime: '19:00:00',
      duration: '60',
      effort: previouslyMerged.effort,
      details: {
        ...previouslyMerged.details!,
        'duration_user_overridden': true,
      },
    );
    final resynced = HealthWorkoutMergeUtils.mergeImportedSession(
      manuallyShortened,
      imported,
    );

    expect(resynced.startTime, '18:00:00');
    expect(resynced.endTime, '19:00:00');
    expect(resynced.duration, '60');
    expect(resynced.details?['duration_user_overridden'], isTrue);
    expect(resynced.details?['total_duration_minutes'], 60);
  });

  test('mantiene tutti gli external id quando fonde import da app diverse', () {
    final firstImport = importedWeightlifting(
      externalId: 'garmin-1',
      sourceName: 'com.garmin.android.apps.connectmobile',
      startTime: '18:00:00',
      endTime: '19:00:00',
    );
    final secondImport = importedWeightlifting(
      externalId: 'strava-1',
      sourceName: 'com.strava',
      startTime: '18:06:00',
      endTime: '19:10:00',
    );

    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      firstImport,
      secondImport,
    );

    expect(merged.details?['external_id'], 'strava-1');
    expect(
      merged.details?['merged_source_workout_ids'],
      containsAll(['garmin-1', 'strava-1']),
    );
    expect(merged.details?['source_part_count'], 2);
  });

  test('non fonde forza strutturata quando la sovrapposizione e debole', () {
    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [manualStrength(startTime: '18:00:00', endTime: '19:00:00')],
      importedWeightlifting(startTime: '18:50:00', endTime: '20:00:00'),
    );

    expect(candidate, isNull);
  });

  test('non fonde sport diversi anche se gli orari si sovrappongono', () {
    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [
        manualStrength(),
      ],
      TrainingSession(
        id: 'run_import',
        sportId: 'running',
        date: '2026-06-12',
        startTime: '18:05:00',
        endTime: '20:00:00',
        duration: '115',
        effort: 5,
        details: const {'source': 'health_sync'},
      ),
    );

    expect(candidate, isNull);
  });

  test('fonde allenamento sci coach con import Garmin snow sports', () {
    final existing = coachSkiSession();
    final imported = importedSnowSports();

    final candidate = HealthWorkoutMergeUtils.bestOverlapMergeCandidate(
      [existing],
      imported,
    );
    final merged = HealthWorkoutMergeUtils.mergeImportedSession(
      candidate!,
      imported,
    );

    expect(candidate.id, existing.id);
    expect(merged.id, existing.id);
    expect(merged.eventId, existing.eventId);
    expect(merged.sportId, 'alpine_skiing');
    expect(merged.startTime, '09:07:00');
    expect(merged.endTime, '12:10:00');
    expect(merged.duration, '183');
    expect(merged.details?['snowCondition'], 'Compatta');
    expect(merged.details?['gatedSkiing'], existing.details?['gatedSkiing']);
    expect(merged.details?['source'], 'health_sync');
    expect(merged.details?['source_name'],
        'com.garmin.android.apps.connectmobile');
    expect(merged.details?['avg_hr'], 132);
    expect(merged.details?['max_hr'], 171);
  });
}
