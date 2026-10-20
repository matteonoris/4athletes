import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DailyStrainResult training(double? score, {int sessions = 1}) =>
      DailyStrainResult(
          score: score,
          status: sessions == 0
              ? StrainScoreStatus.noTraining
              : StrainScoreStatus.ok,
          confidence: 1,
          components: {'sessionCount': sessions},
          warnings: []);
  DailyMovementInput steps(int value) =>
      DailyMovementInput(totalSteps: value, outsideWorkoutSteps: value);

  test('agreed examples and cap are exact', () {
    expect(
        applyDailyMovementToStrain(training(0, sessions: 0), steps(10000))
            .score,
        10);
    expect(applyDailyMovementToStrain(training(60), steps(10000)).score, 64);
    expect(applyDailyMovementToStrain(training(80), steps(20000)).score, 84);
    expect(applyDailyMovementToStrain(training(80), steps(50000)).score, 84);
  });
  test('workout steps are not added a second time', () {
    final result = applyDailyMovementToStrain(training(60),
        const DailyMovementInput(totalSteps: 20000, outsideWorkoutSteps: 5000));
    expect(result.score, 62);
    expect(result.components['dailyMovement']['score'], 5);
  });
  test(
      'missing steps preserve training and do not fabricate a zero on rest days',
      () {
    expect(
        applyDailyMovementToStrain(training(60), const DailyMovementInput())
            .score,
        60);
    final unknown = applyDailyMovementToStrain(
        training(0, sessions: 0), const DailyMovementInput());
    expect(unknown.score, isNull);
    expect(unknown.status, StrainScoreStatus.insufficientData);
    expect(unknown.warnings, contains('daily_steps_unavailable'));
    expect(applyDailyMovementToStrain(training(0, sessions: 0), steps(0)).score,
        0);
  });
  test('steps cannot mask an unscorable training session', () {
    expect(
        applyDailyMovementToStrain(training(null), steps(10000)).score, isNull);
  });
  test('inconsistent counts are unavailable, not a negative movement load', () {
    for (final input in [
      const DailyMovementInput(totalSteps: -1, outsideWorkoutSteps: 0),
      const DailyMovementInput(totalSteps: 200, outsideWorkoutSteps: 201),
      const DailyMovementInput(totalSteps: 200, outsideWorkoutSteps: -1),
    ]) {
      expect(applyDailyMovementToStrain(training(60), input).score, 60);
    }
  });
  test('combination is monotonic and bounded, including training at 100', () {
    for (final base in [0.0, 20.0, 60.0, 100.0]) {
      var previous = base;
      for (var count = 0; count <= 50000; count += 1000) {
        final result = applyDailyMovementToStrain(training(base), steps(count));
        expect(result.score, inInclusiveRange(previous, 100));
        previous = result.score!;
      }
    }
  });
  test('daily calculator includes movement on a day without workouts', () {
    final result = calculateDailyStrain(
        '2026-10-18', [], const AthleteStrainProfile(athleteId: 'athlete'), [],
        dailyMovement: steps(15000));
    expect(result.score, 15);
    expect(result.components['trainingScore'], 0);
    expect(result.confidence, lessThanOrEqualTo(0.5));
    expect(result.warnings, contains('daily_steps_load_estimated'));
  });
}
