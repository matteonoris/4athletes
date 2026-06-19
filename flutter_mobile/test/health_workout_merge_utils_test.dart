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
  }) {
    return TrainingSession(
      id: id,
      sportId: 'weightlifting',
      date: '2026-06-12',
      startTime: startTime,
      endTime: endTime,
      duration: '137',
      effort: 5,
      details: const {
        'source': 'health_sync',
        'external_id': 'wearable-1',
        'source_name': 'com.thirdparty.watch',
        'active_duration_seconds': 8220,
        'avg_hr': 90,
        'max_hr': 133,
        'hr_samples': [
          {'time': 1781280360000, 'bpm': 90}
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
