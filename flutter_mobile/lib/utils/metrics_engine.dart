import 'dart:math' as math;

export 'scoring/algorithm_config.dart';
export 'scoring/math_helpers.dart';
export 'scoring/recovery_score_calculator.dart';
export 'scoring/scoring_engine.dart';
export 'scoring/scoring_types.dart';
export 'scoring/sleep_need_calculator.dart';
export 'scoring/sleep_score_calculator.dart';
export 'scoring/strain_score_calculator.dart';
export 'scoring/strain_sport_mapping.dart';
export 'scoring/time_helpers.dart';

import 'scoring/algorithm_config.dart';
import 'scoring/recovery_score_calculator.dart';
import 'scoring/scoring_types.dart';
import 'scoring/sleep_score_calculator.dart';

class AthleteMetricsEngine {
  final AlgorithmConfig config;

  const AthleteMetricsEngine({this.config = defaultAlgorithmConfig});

  double calculateSleepScore({
    required double totalSleepTime,
    required double targetSleepTime,
    required double deepSleepTime,
    required double remSleepTime,
    required double timeInBed,
    required DateTime sleepOnsetTime,
    required DateTime avgSleepOnsetTime,
  }) {
    final today = DailyWearableData(
      date: _dateKey(sleepOnsetTime),
      totalSleepTimeMinutes: totalSleepTime,
      deepSleepMinutes: deepSleepTime,
      remSleepMinutes: remSleepTime,
      timeInBedMinutes: timeInBed,
      sleepOnsetTimestamp: sleepOnsetTime,
      sleepWakeTimestamp:
          sleepOnsetTime.add(Duration(minutes: timeInBed.round())),
    );
    final history = [
      DailyWearableData(
        date: _dateKey(avgSleepOnsetTime.subtract(const Duration(days: 1))),
        totalSleepTimeMinutes: targetSleepTime,
        sleepOnsetTimestamp: avgSleepOnsetTime,
        sleepWakeTimestamp:
            avgSleepOnsetTime.add(Duration(minutes: targetSleepTime.round())),
      ),
      DailyWearableData(
        date: _dateKey(avgSleepOnsetTime.subtract(const Duration(days: 2))),
        totalSleepTimeMinutes: targetSleepTime,
        sleepOnsetTimestamp: avgSleepOnsetTime,
        sleepWakeTimestamp:
            avgSleepOnsetTime.add(Duration(minutes: targetSleepTime.round())),
      ),
      DailyWearableData(
        date: _dateKey(avgSleepOnsetTime.subtract(const Duration(days: 3))),
        totalSleepTimeMinutes: targetSleepTime,
        sleepOnsetTimestamp: avgSleepOnsetTime,
        sleepWakeTimestamp:
            avgSleepOnsetTime.add(Duration(minutes: targetSleepTime.round())),
      ),
      DailyWearableData(
        date: _dateKey(avgSleepOnsetTime.subtract(const Duration(days: 4))),
        totalSleepTimeMinutes: targetSleepTime,
        sleepOnsetTimestamp: avgSleepOnsetTime,
        sleepWakeTimestamp:
            avgSleepOnsetTime.add(Duration(minutes: targetSleepTime.round())),
      ),
    ];
    final sleepNeed = DailySleepNeedResult(
      valueMinutes: targetSleepTime,
      personalBaselineMinutes: targetSleepTime,
      sleepDebtMinutes: config.confidence.min,
      dailyStrainAdjustmentMinutes: config.confidence.min,
      napsDeductionMinutes: config.confidence.min,
      confidence: config.confidence.max,
      warnings: const [],
    );
    final result = calculateSleepScoreResult(
      const AthleteProfile(athleteId: 'legacy', timezone: 'local'),
      today,
      history,
      sleepNeed,
      config: config,
    );
    return result.score ?? config.score.min;
  }

  double? calculateRecoveryScore({
    required bool isLutealPhase,
    required double? rhrToday,
    required List<double> rhrHistory,
    required double? tempToday,
    required List<double> tempHistory,
    required double? hrvToday,
    required List<double> hrvHistory,
    required double sleepScore,
    required double? respToday,
    required List<double> respHistory,
    required double? spo2Today,
    required List<double> spo2History,
  }) {
    final historyLength = [
      rhrHistory.length,
      tempHistory.length,
      hrvHistory.length,
      respHistory.length,
      spo2History.length,
    ].fold<int>(0, math.max);

    final history = List<DailyWearableData>.generate(historyLength, (index) {
      final date =
          DateTime.now().subtract(Duration(days: historyLength - index));
      return DailyWearableData(
        date: _dateKey(date),
        totalSleepTimeMinutes: config.sleepNeed.defaultSleepBaselineMinutes,
        restingHeartRateBpm: _valueAt(rhrHistory, index, historyLength),
        skinTemperatureCelsius: _valueAt(tempHistory, index, historyLength),
        hrvRmssdMs: _valueAt(hrvHistory, index, historyLength),
        respiratoryRate: _valueAt(respHistory, index, historyLength),
        spo2Percent: _valueAt(spo2History, index, historyLength),
      );
    });
    final today = DailyWearableData(
      date: _dateKey(DateTime.now()),
      totalSleepTimeMinutes: config.sleepNeed.defaultSleepBaselineMinutes,
      restingHeartRateBpm: rhrToday,
      skinTemperatureCelsius: tempToday,
      hrvRmssdMs: hrvToday,
      respiratoryRate: respToday,
      spo2Percent: spo2Today,
    );
    final sleep = ScoreResult(
      score: sleepScore,
      status: ScoreStatus.ok,
      confidence: config.confidence.max,
      components: const {},
      warnings: const [],
    );
    final result = calculateRecoveryScoreResult(
      AthleteProfile(
        athleteId: 'legacy',
        sex: isLutealPhase ? Sex.female : Sex.unknown,
        isLutealPhase: isLutealPhase,
        timezone: 'local',
      ),
      today,
      history,
      sleep,
      config: config,
    );
    return result.score;
  }

  static String _dateKey(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  static double? _valueAt(List<double> values, int index, int fullLength) {
    final offset = fullLength - values.length;
    final valueIndex = index - offset;
    if (valueIndex < 0 || valueIndex >= values.length) return null;
    return values[valueIndex];
  }
}
