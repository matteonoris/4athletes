import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/strain_session_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('import Health senza RPE non usa effort placeholder come RPE', () {
    final input = workoutSessionInputFromTrainingSession(
      TrainingSession(
        id: 'health-1',
        sportId: 'running',
        date: '2026-06-12',
        startTime: '08:00',
        endTime: '09:00',
        duration: '60',
        effort: 5,
        details: const {
          'source': 'health_sync',
          'avg_hr': 145,
        },
      ),
      athleteId: 'athlete-1',
    );

    expect(input.rpe, isNull);
    expect(input.avgHeartRateBpm, 145);
  });

  test('sessione manuale storica usa effort come RPE quando details.rpe manca',
      () {
    final input = workoutSessionInputFromTrainingSession(
      TrainingSession(
        id: 'manual-1',
        sportId: 'running',
        date: '2026-06-12',
        startTime: '08:00',
        endTime: '09:00',
        duration: '60',
        effort: 7,
      ),
      athleteId: 'athlete-1',
    );

    expect(input.rpe, 7);
  });

  test('RPE zero salvato come placeholder viene trattato come mancante', () {
    final input = workoutSessionInputFromTrainingSession(
      TrainingSession(
        id: 'coach-1',
        sportId: 'dryland',
        date: '2026-06-12',
        startTime: '08:00',
        endTime: '09:00',
        duration: '60',
        effort: 0,
        details: const {'rpe': 0},
      ),
      athleteId: 'athlete-1',
    );

    expect(input.rpe, isNull);
  });
}
