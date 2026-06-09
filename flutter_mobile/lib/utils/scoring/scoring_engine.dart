import 'algorithm_config.dart';
import 'recovery_score_calculator.dart';
import 'scoring_types.dart';
import 'sleep_need_calculator.dart';
import 'sleep_score_calculator.dart';

RecoveryAndSleepResult calculateRecoveryAndSleep(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final dailySleepNeed = calculateDailySleepNeed(
    today,
    historicalData,
    config: config,
  );
  final sleepScore = calculateSleepScoreResult(
    profile,
    today,
    historicalData,
    dailySleepNeed,
    config: config,
  );
  final recoveryScore = calculateRecoveryScoreResult(
    profile,
    today,
    historicalData,
    sleepScore,
    config: config,
  );

  return RecoveryAndSleepResult(
    sleepScore: sleepScore,
    recoveryScore: recoveryScore,
    dailySleepNeed: dailySleepNeed,
    appliedConfigVersion: config.version,
  );
}
