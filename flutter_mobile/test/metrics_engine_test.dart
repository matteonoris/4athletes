import 'dart:math' as math;

import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = AthleteProfile(
    athleteId: 'athlete-1',
    sex: Sex.female,
    timezone: 'Europe/Rome',
  );

  test('cold start returns provisional sleep and calibration recovery', () {
    final history = _makeHistory(2);
    final today = _makeDay(3);
    final result = calculateRecoveryAndSleep(profile, today, history);

    expect(result.sleepScore.score, isNotNull);
    expect(result.sleepScore.status, ScoreStatus.partialData);
    expect(result.recoveryScore.score, isNull);
    expect(result.recoveryScore.status, ScoreStatus.calibrationPhase);
  });

  test('safe standard deviation enforces minimum value', () {
    final std = safeStandardDeviation(
      [10, 10, 10],
      defaultAlgorithmConfig.zScore.minStdDev.restingHeartRateBpm,
    );
    final z = clippedZScore(
      value: 11,
      mean: 10,
      standardDeviation: std!,
      minStdDev: defaultAlgorithmConfig.zScore.minStdDev.restingHeartRateBpm,
      lowerClip: defaultAlgorithmConfig.zScore.lowerClip,
      upperClip: defaultAlgorithmConfig.zScore.upperClip,
    );

    expect(std, defaultAlgorithmConfig.zScore.minStdDev.restingHeartRateBpm);
    expect(z, 2);
  });

  test('valid HRV is transformed in log space', () {
    final history = _makeHistory(
      6,
      mutate: (day, index) => _copyDay(day, hrvRmssdMs: 50 + index * 5),
    );
    final today = _makeDay(7, hrvRmssdMs: 90);
    final result = calculateRecoveryAndSleep(profile, today, history);
    final hrvComponent = result.recoveryScore.components['hrv'] as Map;
    final details = hrvComponent['details'] as Map;

    expect(result.recoveryScore.score, isNotNull);
    expect((details['lnToday'] as double) - math.log(90), closeTo(0, 0.000001));
  });

  test('invalid HRV <= 0 is excluded without breaking recovery', () {
    final history = _makeHistory(6);
    final today = _makeDay(7, hrvRmssdMs: 0);
    final result = calculateRecoveryAndSleep(profile, today, history);
    final hrvComponent = result.recoveryScore.components['hrv'] as Map;

    expect(hrvComponent['used'], isFalse);
    expect(result.recoveryScore.warnings, contains('invalid_hrv_rmssd'));
    expect(result.recoveryScore.score, isNotNull);
  });

  test('sleep debt uses exponential decay and caps at 90 minutes', () {
    final history = _makeHistory(
      14,
      mutate: (day, _) => _copyDay(
        day,
        totalSleepTimeMinutes: 240,
        previousDayStrainScore: 100,
      ),
    );
    final need = calculateDailySleepNeed(_makeDay(15), history);

    expect(
      need.sleepDebtMinutes,
      defaultAlgorithmConfig.sleepNeed.maxSleepDebtMinutes,
    );
    expect(need.warnings, contains('sleep_debt_capped'));
  });

  test('undefined and empty naps produce zero deduction', () {
    expect(calculateNapsDeduction(null), 0);
    expect(calculateNapsDeduction(const []), 0);
  });

  test('circadian regularity handles midnight crossing', () {
    final mean = circularMeanMinutes([1430, 10], defaultAlgorithmConfig);
    expect(mean, isNotNull);

    final deviation = circularAbsoluteDifferenceMinutes(
      5,
      mean!,
      defaultAlgorithmConfig,
    );
    expect(deviation, lessThanOrEqualTo(10));
  });

  test('sleep regularity uses bedtime and wake time over four nights', () {
    final history = [
      _makeDay(1),
      _makeDay(2),
      _makeDay(3),
    ];
    final today = _makeDay(
      4,
      sleepOnsetTimestamp: DateTime(2026, 5, 5, 0, 30),
      sleepWakeTimestamp: DateTime(2026, 5, 5, 8, 30),
    );

    final result = calculateRecoveryAndSleep(profile, today, history);
    final regularity =
        result.sleepScore.components['circadianRegularity'] as Map;

    expect(regularity['value'], closeTo(77.5, 0.05));
    expect(regularity['details']['windowNightCount'], 4);
    expect(
      regularity['details']['wakeDeviationMinutes'],
      closeTo(22.5, 0.05),
    );
  });

  test('missing SpO2 is warned and remaining recovery components are used', () {
    final history = _makeHistory(
      8,
      mutate: (_, index) => _makeDay(index + 1, spo2Percent: null),
    );
    final today = _makeDay(9, spo2Percent: null);
    final result = calculateRecoveryAndSleep(profile, today, history);
    final spo2Component = result.recoveryScore.components['spo2'] as Map;

    expect(spo2Component['used'], isFalse);
    expect(result.recoveryScore.warnings, contains('spo2_unavailable'));
    expect(result.recoveryScore.score, isNotNull);
  });

  test('luteal phase adjustment is applied only when explicit', () {
    final history = _makeHistory(8);
    final today = _makeDay(
      9,
      restingHeartRateBpm: 52,
      skinTemperatureCelsius: 36.9,
      hrvRmssdMs: 60,
    );
    const adjustedProfile = AthleteProfile(
      athleteId: 'athlete-1',
      sex: Sex.female,
      isLutealPhase: true,
      timezone: 'Europe/Rome',
    );
    final result = calculateRecoveryAndSleep(adjustedProfile, today, history);
    final rhr = result.recoveryScore.components['restingHeartRate'] as Map;
    final hrv = result.recoveryScore.components['hrv'] as Map;
    final rhrDetails = rhr['details'] as Map;
    final hrvDetails = hrv['details'] as Map;

    expect(
      result.recoveryScore.warnings,
      contains('luteal_phase_adjustment_applied'),
    );
    expect(rhrDetails['todayValue'], 50);
    expect(
      (hrvDetails['lnToday'] as double) - math.log(66),
      closeTo(0, 0.000001),
    );
  });

  test('final scores are bounded to 0-100 with extreme inputs', () {
    final history = _makeHistory(30);
    final today = _makeDay(
      31,
      totalSleepTimeMinutes: 1200,
      timeInBedMinutes: 1200,
      deepSleepMinutes: 500,
      remSleepMinutes: 500,
      restingHeartRateBpm: 220,
      hrvRmssdMs: 1,
      skinTemperatureCelsius: 45,
      respiratoryRate: 60,
      spo2Percent: 50,
      previousDayStrainScore: 100,
    );
    final result = calculateRecoveryAndSleep(profile, today, history);

    expect(result.sleepScore.score, inInclusiveRange(0, 100));
    expect(result.recoveryScore.score, inInclusiveRange(0, 100));
  });

  test('neutral recovery baseline maps to about 70 points', () {
    final history = _makeHistory(30);
    final today = _makeDay(31);
    final result = calculateRecoveryAndSleep(profile, today, history);

    expect(result.recoveryScore.score, closeTo(70, 1));
  });
}

List<DailyWearableData> _makeHistory(
  int count, {
  DailyWearableData Function(DailyWearableData day, int index)? mutate,
}) {
  return List<DailyWearableData>.generate(count, (index) {
    final day = _makeDay(index + 1);
    return mutate == null ? day : mutate(day, index);
  });
}

DailyWearableData _makeDay(
  int dayOfMonth, {
  double? totalSleepTimeMinutes = 480,
  double? deepSleepMinutes = 95,
  double? remSleepMinutes = 110,
  double? timeInBedMinutes = 510,
  double? restingHeartRateBpm = 50,
  double? hrvRmssdMs = 70,
  double? skinTemperatureCelsius = 36.5,
  double? respiratoryRate = 14,
  double? spo2Percent = 98,
  double? previousDayStrainScore = 40,
  DateTime? sleepOnsetTimestamp,
  DateTime? sleepWakeTimestamp,
}) {
  final onset = sleepOnsetTimestamp ?? DateTime(2026, 5, dayOfMonth, 23, 30);
  return DailyWearableData(
    date: '2026-05-${dayOfMonth.toString().padLeft(2, '0')}',
    totalSleepTimeMinutes: totalSleepTimeMinutes,
    deepSleepMinutes: deepSleepMinutes,
    remSleepMinutes: remSleepMinutes,
    timeInBedMinutes: timeInBedMinutes,
    sleepOnsetTimestamp: onset,
    sleepWakeTimestamp:
        sleepWakeTimestamp ?? onset.add(const Duration(hours: 8)),
    naps: const [],
    restingHeartRateBpm: restingHeartRateBpm,
    hrvRmssdMs: hrvRmssdMs,
    skinTemperatureCelsius: skinTemperatureCelsius,
    respiratoryRate: respiratoryRate,
    spo2Percent: spo2Percent,
    previousDayStrainScore: previousDayStrainScore,
  );
}

DailyWearableData _copyDay(
  DailyWearableData day, {
  double? totalSleepTimeMinutes,
  double? deepSleepMinutes,
  double? remSleepMinutes,
  double? timeInBedMinutes,
  double? restingHeartRateBpm,
  double? hrvRmssdMs,
  double? skinTemperatureCelsius,
  double? respiratoryRate,
  double? spo2Percent,
  double? previousDayStrainScore,
}) {
  return DailyWearableData(
    date: day.date,
    totalSleepTimeMinutes: totalSleepTimeMinutes ?? day.totalSleepTimeMinutes,
    deepSleepMinutes: deepSleepMinutes ?? day.deepSleepMinutes,
    remSleepMinutes: remSleepMinutes ?? day.remSleepMinutes,
    timeInBedMinutes: timeInBedMinutes ?? day.timeInBedMinutes,
    sleepOnsetTimestamp: day.sleepOnsetTimestamp,
    sleepWakeTimestamp: day.sleepWakeTimestamp,
    naps: day.naps,
    restingHeartRateBpm: restingHeartRateBpm ?? day.restingHeartRateBpm,
    hrvRmssdMs: hrvRmssdMs ?? day.hrvRmssdMs,
    skinTemperatureCelsius:
        skinTemperatureCelsius ?? day.skinTemperatureCelsius,
    respiratoryRate: respiratoryRate ?? day.respiratoryRate,
    spo2Percent: spo2Percent ?? day.spo2Percent,
    previousDayStrainScore:
        previousDayStrainScore ?? day.previousDayStrainScore,
  );
}
