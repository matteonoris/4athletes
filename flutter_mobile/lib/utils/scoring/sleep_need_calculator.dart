import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';

class BaselineResult {
  final double valueMinutes;
  final double confidence;
  final int validNights;
  final List<String> warnings;

  const BaselineResult({
    required this.valueMinutes,
    required this.confidence,
    required this.validNights,
    required this.warnings,
  });
}

class SleepDebtResult {
  final double valueMinutes;
  final int usedDays;
  final List<String> warnings;

  const SleepDebtResult({
    required this.valueMinutes,
    required this.usedDays,
    required this.warnings,
  });
}

DailySleepNeedResult calculateDailySleepNeed(
  DailyWearableData today,
  HistoricalDailyData historicalData, {
  AthleteProfile? profile,
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final history = _excludeToday(historicalData, today.date);
  final warnings = <String>[];
  final validHistoryNights = _validBaselineSleepValues(history, config).length;

  if (validHistoryNights < config.history.minCalibrationDays) {
    warnings.add('sleep_need_history_below_minimum_valid_nights');
  } else if (validHistoryNights < config.history.rollingWindowDays) {
    warnings.add('sleep_need_history_partial_valid_nights');
  }

  final baseline = calculatePersonalBaseline(
    history,
    profile: profile,
    config: config,
  );
  warnings.addAll(baseline.warnings);

  final sleepDebt = calculateSleepDebt(
    history,
    profile: profile,
    config: config,
  );
  warnings.addAll(sleepDebt.warnings);

  final dailyStrainAdjustmentMinutes = calculateDailyStrainAdjustment(
    today,
    config: config,
    warnings: warnings,
  );
  // Kept in the existing result field for API compatibility. In v2 this is
  // observed valid nap sleep, not a deduction from the athlete's sleep need.
  final validNapMinutes = calculateNapsDeduction(
    today.naps,
    config: config,
    warnings: warnings,
  );

  final unclampedNeed = baseline.valueMinutes +
      math.max(config.confidence.min, sleepDebt.valueMinutes) +
      dailyStrainAdjustmentMinutes;
  final valueMinutes = clampDouble(
    unclampedNeed,
    config.sleepNeed.minDailySleepNeedMinutes,
    config.sleepNeed.maxDailySleepNeedMinutes,
  );

  if (valueMinutes != unclampedNeed) {
    warnings.add('daily_sleep_need_clamped_to_config_bounds');
  }

  var confidence = baseline.confidence;
  if (validHistoryNights < config.history.rollingWindowDays) {
    confidence *= config.confidence.shortHistoryMultiplier;
  }
  if (sleepDebt.usedDays < config.history.minCalibrationDays) {
    confidence *= config.confidence.missingInputMultiplier;
  }

  return DailySleepNeedResult(
    valueMinutes: valueMinutes,
    personalBaselineMinutes: baseline.valueMinutes,
    sleepDebtMinutes: sleepDebt.valueMinutes,
    dailyStrainAdjustmentMinutes: dailyStrainAdjustmentMinutes,
    napsDeductionMinutes: validNapMinutes,
    confidence: clampDouble(
      confidence,
      config.confidence.min,
      config.confidence.max,
    ),
    warnings: uniqueWarnings(warnings),
  );
}

BaselineResult calculatePersonalBaseline(
  HistoricalDailyData historicalData, {
  AthleteProfile? profile,
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final validValues = _validBaselineSleepValues(historicalData, config);
  final ageTarget = athleteSleepTargetMinutes(profile, config: config);
  final observedPercentile = percentile(
    validValues,
    config.sleepNeed.personalBaselinePercentile,
  );
  final evidenceInformedBaseline = math.max(
    ageTarget,
    observedPercentile ?? ageTarget,
  );
  final boundedBaseline = clampDouble(
    evidenceInformedBaseline,
    config.sleepNeed.minDailySleepNeedMinutes,
    config.sleepNeed.maxDailySleepNeedMinutes,
  );

  if (validValues.length >= config.sleepNeed.minValidBaselineNights) {
    return BaselineResult(
      valueMinutes: boundedBaseline,
      confidence: config.confidence.max,
      validNights: validValues.length,
      warnings: evidenceInformedBaseline == boundedBaseline
          ? const []
          : const ['sleep_baseline_clamped_to_config_bounds'],
    );
  }

  if (validValues.length >= config.sleepNeed.partialBaselineMinNights) {
    return BaselineResult(
      valueMinutes: boundedBaseline,
      confidence: config.confidence.partialBaselineMultiplier,
      validNights: validValues.length,
      warnings: const ['sleep_baseline_partial_valid_nights'],
    );
  }

  return BaselineResult(
    valueMinutes: ageTarget,
    confidence: config.confidence.fallbackBaselineMultiplier,
    validNights: validValues.length,
    warnings: const ['sleep_baseline_fallback_age_target_used'],
  );
}

SleepDebtResult calculateSleepDebt(
  HistoricalDailyData historicalData, {
  AthleteProfile? profile,
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final warnings = <String>[];
  final debtWindow =
      historicalData.takeLast(config.history.sleepDebtWindowDays);
  var weightedBalance = config.confidence.min;
  var usedDays = 0;

  for (var index = 0; index < debtWindow.length; index++) {
    final day = debtWindow[index];
    final actualSleep24h = calculateTotalSleep24hMinutes(
      day,
      config: config,
      warnings: warnings,
    );
    if (!isFiniteNumber(actualSleep24h)) {
      warnings.add('sleep_debt_day_skipped_invalid_total_sleep');
      continue;
    }

    final historyBeforeDay = historicalData.sublist(
      0,
      historicalData.length - debtWindow.length + index,
    );
    final personalBaseline = calculatePersonalBaseline(
      historyBeforeDay,
      profile: profile,
      config: config,
    ).valueMinutes;
    final strainAdjustment =
        calculateDailyStrainAdjustment(day, config: config);
    final historicalReferenceNeedForDay = clampDouble(
      personalBaseline + strainAdjustment,
      config.sleepNeed.minDailySleepNeedMinutes,
      config.sleepNeed.maxDailySleepNeedMinutes,
    );
    // Signed balance: a surplus is negative and repays older positive
    // deficits. The most recent completed day has age zero and full weight.
    final dailyDeficit = historicalReferenceNeedForDay - actualSleep24h!;
    final ageInDays = debtWindow.length - 1 - index;
    weightedBalance += dailyDeficit *
        math.exp(-config.sleepNeed.sleepDebtDecayLambda * ageInDays);
    usedDays++;
  }

  final valueMinutes = clampDouble(
    weightedBalance,
    -config.sleepNeed.maxSleepDebtMinutes,
    config.sleepNeed.maxSleepDebtMinutes,
  );
  if (weightedBalance > config.sleepNeed.maxSleepDebtMinutes) {
    warnings.add('sleep_debt_capped');
  } else if (weightedBalance < -config.sleepNeed.maxSleepDebtMinutes) {
    warnings.add('sleep_surplus_capped');
  }

  return SleepDebtResult(
    valueMinutes: valueMinutes,
    usedDays: usedDays,
    warnings: uniqueWarnings(warnings),
  );
}

double calculateNapsDeduction(
  List<Nap>? naps, {
  AlgorithmConfig config = defaultAlgorithmConfig,
  List<String>? warnings,
}) {
  if (naps == null || naps.isEmpty) return config.confidence.min;

  final rawDuration = naps.fold<double>(config.confidence.min, (sum, nap) {
    if (!isFiniteNumber(nap.durationMinutes) ||
        nap.durationMinutes <= config.confidence.min ||
        !nap.endTimestamp.isAfter(nap.startTimestamp)) {
      warnings?.add('invalid_nap_duration_ignored');
      return sum;
    }
    return sum + nap.durationMinutes;
  });
  final cappedDuration =
      math.min(rawDuration, config.sleepNeed.maxNapsDeductionMinutes);

  if (cappedDuration < rawDuration) {
    warnings?.add('nap_sleep_credit_capped');
  }

  return cappedDuration;
}

double calculateDailyStrainAdjustment(
  DailyWearableData day, {
  AlgorithmConfig config = defaultAlgorithmConfig,
  List<String>? warnings,
}) {
  // The v2 evidence-informed configuration disables the previous unvalidated
  // strain-to-sleep-minutes curve. Do not emit missing-input warnings when the
  // feature is disabled.
  if (config.sleepNeed.maxStrainSleepNeedMinutes <= config.confidence.min) {
    return config.confidence.min;
  }

  final strainScore = day.previousDayStrainScore;
  if (!isFiniteNumber(strainScore)) {
    warnings?.add('missing_previous_day_strain_score');
    if ((day.previousDayWorkoutCount ?? 0) > 0) {
      warnings?.add('previous_day_workout_without_strain_score');
      return config.sleepNeed.maxStrainSleepNeedMinutes *
          math.pow(
            config.strainScore.missingStrainWorkoutFallbackScore /
                config.physiology.previousDayStrainScore.max,
            1.2,
          );
    }
    return config.confidence.min;
  }

  final clampedStrain = clampDouble(
    strainScore!,
    config.physiology.previousDayStrainScore.min,
    config.physiology.previousDayStrainScore.max,
  );
  if (clampedStrain != strainScore) {
    warnings?.add('previous_day_strain_score_clamped');
  }

  return config.sleepNeed.maxStrainSleepNeedMinutes *
      math.pow(
        clampedStrain / config.physiology.previousDayStrainScore.max,
        1.2,
      );
}

double athleteSleepTargetMinutes(
  AthleteProfile? profile, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final ageYears = profile?.ageYears;
  if (ageYears != null &&
      ageYears >= 0 &&
      ageYears <= config.sleepNeed.adolescentMaxAgeYears) {
    return config.sleepNeed.adolescentAthleteTargetMinutes;
  }
  return config.sleepNeed.adultAthleteTargetMinutes;
}

double? calculateTotalSleep24hMinutes(
  DailyWearableData day, {
  AlgorithmConfig config = defaultAlgorithmConfig,
  List<String>? warnings,
}) {
  final totalSleep = day.totalSleepTimeMinutes;
  if (!config.physiology.totalSleepTimeMinutes.contains(totalSleep)) {
    return null;
  }
  final validNapMinutes = calculateNapsDeduction(
    day.naps,
    config: config,
    warnings: warnings,
  );
  return totalSleep! + validNapMinutes;
}

List<double> _validBaselineSleepValues(
  HistoricalDailyData historicalData,
  AlgorithmConfig config,
) {
  return historicalData
      .takeLast(config.history.rollingWindowDays)
      .map((day) => day.totalSleepTimeMinutes)
      .where(config.sleepNeed.validBaselineSleepMinutes.contains)
      .map((value) => value!.toDouble())
      .toList(growable: false);
}

List<DailyWearableData> _excludeToday(
  HistoricalDailyData historicalData,
  String todayDate,
) {
  return historicalData.where((day) => day.date != todayDate).toList();
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return const [];
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}
