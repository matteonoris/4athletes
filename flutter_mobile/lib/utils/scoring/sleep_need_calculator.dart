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
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final history = _excludeToday(historicalData, today.date);
  final warnings = <String>[];

  if (history.length < config.history.minCalibrationDays) {
    warnings.add('history_less_than_4_days');
  } else if (history.length < config.history.rollingWindowDays) {
    warnings.add('partial_history_less_than_30_days');
  }

  final baseline = calculatePersonalBaseline(history, config: config);
  warnings.addAll(baseline.warnings);

  final sleepDebt = calculateSleepDebt(history, config: config);
  warnings.addAll(sleepDebt.warnings);

  final dailyStrainAdjustmentMinutes = calculateDailyStrainAdjustment(
    today,
    config: config,
    warnings: warnings,
  );
  final napsDeductionMinutes = calculateNapsDeduction(
    today.naps,
    config: config,
    warnings: warnings,
  );

  final unclampedNeed = baseline.valueMinutes +
      sleepDebt.valueMinutes +
      dailyStrainAdjustmentMinutes -
      napsDeductionMinutes;
  final valueMinutes = clampDouble(
    unclampedNeed,
    config.sleepNeed.minDailySleepNeedMinutes,
    config.sleepNeed.maxDailySleepNeedMinutes,
  );

  if (valueMinutes != unclampedNeed) {
    warnings.add('daily_sleep_need_clamped_to_config_bounds');
  }

  var confidence = baseline.confidence;
  if (history.length < config.history.rollingWindowDays) {
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
    napsDeductionMinutes: napsDeductionMinutes,
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
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final validValues = historicalData
      .takeLast(config.history.rollingWindowDays)
      .map((day) => day.totalSleepTimeMinutes)
      .where(config.sleepNeed.validBaselineSleepMinutes.contains)
      .map((value) => value!.toDouble())
      .toList(growable: false);

  if (validValues.length >= config.sleepNeed.minValidBaselineNights) {
    return BaselineResult(
      valueMinutes:
          rollingMean(validValues, config.history.rollingWindowDays) ??
              config.sleepNeed.defaultSleepBaselineMinutes,
      confidence: config.confidence.max,
      validNights: validValues.length,
      warnings: const [],
    );
  }

  if (validValues.length >= config.sleepNeed.partialBaselineMinNights) {
    return BaselineResult(
      valueMinutes:
          rollingMean(validValues, config.history.rollingWindowDays) ??
              config.sleepNeed.defaultSleepBaselineMinutes,
      confidence: config.confidence.partialBaselineMultiplier,
      validNights: validValues.length,
      warnings: const ['sleep_baseline_partial_4_to_6_valid_nights'],
    );
  }

  return BaselineResult(
    valueMinutes: config.sleepNeed.defaultSleepBaselineMinutes,
    confidence: config.confidence.fallbackBaselineMultiplier,
    validNights: validValues.length,
    warnings: const ['sleep_baseline_fallback_default_used'],
  );
}

SleepDebtResult calculateSleepDebt(
  HistoricalDailyData historicalData, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final warnings = <String>[];
  final debtWindow =
      historicalData.takeLast(config.history.sleepDebtWindowDays);
  var weightedDebt = config.confidence.min;
  var usedDays = 0;

  for (var index = 0; index < debtWindow.length; index++) {
    final day = debtWindow[index];
    final actualSleep = day.totalSleepTimeMinutes;
    if (!config.physiology.totalSleepTimeMinutes.contains(actualSleep)) {
      warnings.add('sleep_debt_day_skipped_invalid_total_sleep');
      continue;
    }

    final historyBeforeDay = historicalData.sublist(
      0,
      historicalData.length - debtWindow.length + index,
    );
    final personalBaseline = calculatePersonalBaseline(
      historyBeforeDay,
      config: config,
    ).valueMinutes;
    final strainAdjustment =
        calculateDailyStrainAdjustment(day, config: config);
    final napsDeduction = calculateNapsDeduction(day.naps, config: config);
    final historicalReferenceNeedForDay = clampDouble(
      personalBaseline + strainAdjustment - napsDeduction,
      config.sleepNeed.minDailySleepNeedMinutes,
      config.sleepNeed.maxDailySleepNeedMinutes,
    );
    final dailyDeficit = math.max(
      config.confidence.min,
      historicalReferenceNeedForDay - actualSleep!,
    );
    final ageInDays = debtWindow.length - index;
    weightedDebt += dailyDeficit *
        math.exp(-config.sleepNeed.sleepDebtDecayLambda * ageInDays);
    usedDays++;
  }

  final valueMinutes =
      math.min(weightedDebt, config.sleepNeed.maxSleepDebtMinutes);
  if (weightedDebt > config.sleepNeed.maxSleepDebtMinutes) {
    warnings.add('sleep_debt_capped');
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
        nap.durationMinutes <= config.confidence.min) {
      warnings?.add('invalid_nap_duration_ignored');
      return sum;
    }
    return sum + nap.durationMinutes;
  });
  final cappedDuration =
      math.min(rawDuration, config.sleepNeed.maxNapsDeductionMinutes);

  if (cappedDuration < rawDuration) {
    warnings?.add('naps_deduction_capped');
  }

  return cappedDuration;
}

double calculateDailyStrainAdjustment(
  DailyWearableData day, {
  AlgorithmConfig config = defaultAlgorithmConfig,
  List<String>? warnings,
}) {
  final strainScore = day.previousDayStrainScore;
  if (!isFiniteNumber(strainScore)) {
    warnings?.add('missing_previous_day_strain_score');
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
      (clampedStrain / config.physiology.previousDayStrainScore.max);
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
