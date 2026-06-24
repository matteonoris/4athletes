import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/strength_pr_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa il PR piu recente invece del valore storico piu alto', () {
    final logs = [
      PRLog(
        id: 'old_high',
        exerciseId: 'back_squat',
        date: '2026-01-10',
        weight: 140,
      ),
      PRLog(
        id: 'current',
        exerciseId: 'back_squat',
        date: '2026-06-01',
        weight: 120,
      ),
    ];

    expect(currentOneRepMaxForExercise('back_squat', logs), 120);
  });

  test('usa il valore profilo quando non ci sono PR log per esercizio', () {
    expect(
      currentOneRepMaxForExercise(
        'deadlift',
        const [],
        profileOneRepMax: {'deadlift': 180},
      ),
      180,
    );
  });

  test('ignora i log di altri esercizi', () {
    final logs = [
      PRLog(
        id: 'bench',
        exerciseId: 'bp',
        date: '2026-06-01',
        weight: 100,
      ),
    ];

    expect(
      currentOneRepMaxForExercise(
        'back_squat',
        logs,
        profileOneRepMax: {'back_squat': 110},
      ),
      110,
    );
  });
}
