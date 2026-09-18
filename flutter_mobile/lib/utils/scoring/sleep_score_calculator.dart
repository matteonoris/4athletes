import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';
import 'sleep_need_calculator.dart';
import 'daily_history.dart';
import 'time_helpers.dart';

ScoreResult calculateSleepScoreResult(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  DailySleepNeedResult dailySleepNeed, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final history = previousDailyHistory(
    historicalData,
    beforeDate: today.date,
    windowDays: config.history.rollingWindowDays,
  );
  final warnings = <String>[...dailySleepNeed.warnings];
  final validHistoryNights = history
      .where((day) => config.physiology.totalSleepTimeMinutes
          .contains(day.totalSleepTimeMinutes))
      .length;

  if (validHistoryNights < config.history.minCalibrationDays) {
    warnings.add('sleep_score_provisional_insufficient_valid_history');
  } else if (validHistoryNights < config.history.rollingWindowDays) {
    warnings.add('sleep_score_partial_valid_history');
  }

  final duration = _calculateDurationScore(today, dailySleepNeed, config);
  final architecture = _calculateArchitectureScore(today, history, config);
  if (architecture.warning.isNotEmpty) warnings.add(architecture.warning);
  final recentAdequacy = _calculateRecentAdequacyScore(
    profile,
    today,
    history,
    dailySleepNeed,
    config,
  );
  final circadianRegularity = _calculateCircadianRegularityScore(
    profile,
    today,
    history,
    config,
  );
  final efficiency = _calculateEfficiencyScore(today, config);

  final combined = combineWeightedValues(
    [
      WeightedValue(
        key: 'duration',
        value: duration.value,
        weight: config.sleepScore.weights.duration,
        warning: duration.warning,
        details: duration.details,
      ),
      WeightedValue(
        key: 'recentAdequacy',
        value: recentAdequacy.value,
        weight: config.sleepScore.weights.recentAdequacy,
        warning: recentAdequacy.warning,
        details: recentAdequacy.details,
      ),
      WeightedValue(
        key: 'circadianRegularity',
        value: circadianRegularity.value,
        weight: config.sleepScore.weights.circadianRegularity,
        warning: circadianRegularity.warning,
        details: circadianRegularity.details,
      ),
      WeightedValue(
        key: 'efficiency',
        value: efficiency.value,
        weight: config.sleepScore.weights.efficiency,
        warning: efficiency.warning,
        details: efficiency.details,
      ),
    ],
    config,
  );
  warnings.addAll(combined.warnings);

  // A previous good week or regular bedtimes cannot score a missing night.
  if (combined.value == null || duration.value == null) {
    return ScoreResult(
      score: null,
      status: ScoreStatus.insufficientData,
      confidence: config.confidence.min,
      components: {
        'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
        'availableWeight': combined.availableWeight,
        'architecture': _architectureComponent(architecture),
        ...combined.components,
      },
      warnings: uniqueWarnings(warnings),
    );
  }

  var confidence = combined.availableWeight * dailySleepNeed.confidence;
  final architectureConfidence =
      (architecture.details['baselineConfidence'] as double?) ?? 0;
  confidence *= config.confidence.missingInputMultiplier +
      (1 - config.confidence.missingInputMultiplier) * architectureConfidence;
  if (validHistoryNights < config.history.minCalibrationDays) {
    confidence *= config.confidence.fallbackSleepBaselineMultiplier;
  } else if (validHistoryNights < config.history.rollingWindowDays) {
    confidence *= config.confidence.shortHistoryMultiplier;
  }

  final unique = uniqueWarnings(warnings);
  final durationCeiling = math.min(
    config.score.max,
    duration.value! + config.sleepScore.maxDurationCompensationPoints,
  );
  final scoreBeforeArchitecture = math.min(combined.value!, durationCeiling);
  final architecturePenalty = architecture.value ?? 0;
  return ScoreResult(
    score: clampDouble(scoreBeforeArchitecture - architecturePenalty,
        config.score.min, config.score.max),
    status: unique.isEmpty && combined.availableWeight >= config.confidence.max
        ? ScoreStatus.ok
        : ScoreStatus.partialData,
    confidence: clampDouble(
      confidence,
      config.confidence.min,
      config.confidence.max,
    ),
    components: {
      'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
      'availableWeight': combined.availableWeight,
      'weightedScoreBeforeLimits': combined.value,
      'durationCeiling': durationCeiling,
      'durationCeilingApplied': combined.value! > durationCeiling,
      'scoreBeforeArchitecture': scoreBeforeArchitecture,
      'architecturePenaltyPoints': architecturePenalty,
      'architecture': _architectureComponent(architecture),
      ...combined.components,
    },
    warnings: unique,
  );
}

_ComponentScore _calculateDurationScore(
  DailyWearableData today,
  DailySleepNeedResult dailySleepNeed,
  AlgorithmConfig config,
) {
  final totalSleep24h = calculateTotalSleep24hMinutes(today, config: config);
  final validNapMinutes = calculateNapsDeduction(today.naps, config: config);
  if (!isFiniteNumber(totalSleep24h) ||
      !dailySleepNeed.valueMinutes.isFinite ||
      dailySleepNeed.valueMinutes <= 0) {
    return _ComponentScore(
      value: null,
      warning: 'invalid_or_missing_total_sleep_time',
      details: {
        'totalSleepTimeMinutes': today.totalSleepTimeMinutes,
        'validNapMinutes': validNapMinutes,
        'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
      },
    );
  }

  return _ComponentScore(
    value: _adequacyScore(totalSleep24h! / dailySleepNeed.valueMinutes, config),
    details: {
      'totalSleepTimeMinutes': today.totalSleepTimeMinutes,
      'validNapMinutes': validNapMinutes,
      'totalSleep24hMinutes': totalSleep24h,
      'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
      'adequacyRatio': totalSleep24h / dailySleepNeed.valueMinutes,
    },
  );
}

_ComponentScore _calculateRecentAdequacyScore(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  DailySleepNeedResult todaySleepNeed,
  AlgorithmConfig config,
) {
  final historyCount =
      _maxInt(0, config.sleepScore.recentAdequacyWindowDays - 1);
  final recentHistory = previousDailyHistory(historicalData,
      beforeDate: today.date, windowDays: historyCount);
  var totalActualMinutes = 0.0;
  var totalNeedMinutes = 0.0;
  var validDayCount = 0;
  var totalDailyAdequacyScores = 0.0;

  for (var index = 0; index < recentHistory.length; index++) {
    final day = recentHistory[index];
    final actualSleep24h = calculateTotalSleep24hMinutes(day, config: config);
    if (!isFiniteNumber(actualSleep24h)) continue;

    final baseline = calculatePersonalBaseline(
      historicalData
          .where((item) => item.date.compareTo(day.date) < 0)
          .toList(),
      profile: profile,
      config: config,
    );
    if (!isFiniteNumber(baseline.valueMinutes) ||
        baseline.valueMinutes <= config.confidence.min) {
      continue;
    }

    totalActualMinutes += actualSleep24h!;
    totalNeedMinutes += baseline.valueMinutes;
    totalDailyAdequacyScores +=
        _adequacyScore(actualSleep24h / baseline.valueMinutes, config);
    validDayCount++;
  }

  final todayActualSleep24h =
      calculateTotalSleep24hMinutes(today, config: config);
  if (isFiniteNumber(todayActualSleep24h) &&
      todaySleepNeed.personalBaselineMinutes > config.confidence.min) {
    totalActualMinutes += todayActualSleep24h!;
    totalNeedMinutes += todaySleepNeed.personalBaselineMinutes;
    totalDailyAdequacyScores += _adequacyScore(
        todayActualSleep24h / todaySleepNeed.personalBaselineMinutes, config);
    validDayCount++;
  }

  final details = <String, dynamic>{
    'validDayCount': validDayCount,
    'minimumValidDays': config.sleepScore.recentAdequacyMinDays,
    'windowDays': config.sleepScore.recentAdequacyWindowDays,
    'totalActualSleep24hMinutes': totalActualMinutes,
    'totalSleepNeedMinutes': totalNeedMinutes,
  };
  if (validDayCount < config.sleepScore.recentAdequacyMinDays ||
      totalNeedMinutes <= config.confidence.min) {
    return _ComponentScore(
      value: null,
      warning: 'recent_sleep_adequacy_insufficient_valid_days',
      details: details,
    );
  }

  final adequacyRatio = totalActualMinutes / totalNeedMinutes;
  return _ComponentScore(
    value: clampDouble(
      totalDailyAdequacyScores / validDayCount,
      config.score.min,
      config.score.max,
    ),
    details: {
      ...details,
      'adequacyRatio': adequacyRatio,
      'method': 'mean_capped_daily_adequacy',
    },
  );
}

_ComponentScore _calculateArchitectureScore(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final settings = config.sleepScore.architecture;
  final validHistory = history
      .where((day) =>
          _hasComparableStages(day, config) &&
          day.sleepStageSource == today.sleepStageSource)
      .toList();
  final baselineConfidence =
      clampDouble(validHistory.length / settings.fullBaselineNights, 0, 1);
  final details = <String, dynamic>{
    'method': 'personal_stage_deficit_penalty',
    'source': today.sleepStageSource,
    'validBaselineNights': validHistory.length,
    'minimumBaselineNights': settings.minBaselineNights,
    'windowDays': config.history.rollingWindowDays,
    'maxPenaltyPoints': settings.maxPenaltyPoints,
    'baselineConfidence': 0.0,
  };
  if (!_hasComparableStages(today, config)) {
    return _ComponentScore(
        value: null,
        warning: 'sleep_architecture_incomplete_invalid_or_unknown_source',
        details: details);
  }
  if (validHistory.length < settings.minBaselineNights) {
    return _ComponentScore(
        value: null,
        warning: 'sleep_architecture_insufficient_personal_history',
        details: details);
  }

  Map<String, dynamic> compareStage(
    double Function(DailyWearableData) minutes, {
    required bool penalizeDeficit,
  }) {
    final stats = medianAndRobustStandardDeviation(
      validHistory
          .map((day) => minutes(day) / day.totalSleepTimeMinutes!)
          .toList(),
      settings.minRatioStandardDeviation,
    )!;
    final todayMinutes = minutes(today);
    final todayRatio = todayMinutes / today.totalSleepTimeMinutes!;
    final deficitZ =
        (stats.median - todayRatio) / stats.robustStandardDeviation;
    final severity = penalizeDeficit
        ? clampDouble(
            (deficitZ - settings.deficitDeadbandZ) /
                (settings.fullPenaltyZ - settings.deficitDeadbandZ),
            0,
            1)
        : 0.0;
    return {
      'todayMinutes': todayMinutes,
      'todayRatio': todayRatio,
      'baselineMedianMinutes': median(validHistory.map(minutes).toList()),
      'baselineMedianRatio': stats.median,
      'expectedMinutesForTonight': stats.median * today.totalSleepTimeMinutes!,
      'robustRatioStandardDeviation': stats.robustStandardDeviation,
      'deficitZ': deficitZ,
      'penaltyPoints':
          severity * settings.maxPenaltyPoints / 2 * baselineConfidence,
      'informationalOnly': !penalizeDeficit,
    };
  }

  // Ratios isolate composition from duration, which already has its own score.
  // Deep and REM cannot cancel each other. Light sleep has no bad/good target.
  final deep =
      compareStage((day) => day.deepSleepMinutes!, penalizeDeficit: true);
  final rem =
      compareStage((day) => day.remSleepMinutes!, penalizeDeficit: true);
  final light =
      compareStage((day) => day.lightSleepMinutes!, penalizeDeficit: false);
  return _ComponentScore(
    value: (deep['penaltyPoints'] as double) + (rem['penaltyPoints'] as double),
    warning: validHistory.length < settings.fullBaselineNights
        ? 'sleep_architecture_partial_personal_history'
        : '',
    details: {
      ...details,
      'baselineConfidence': baselineConfidence,
      'deep': deep,
      'rem': rem,
      'light': light
    },
  );
}

bool _hasComparableStages(DailyWearableData day, AlgorithmConfig config) {
  final total = day.totalSleepTimeMinutes;
  final stages = [
    day.deepSleepMinutes,
    day.remSleepMinutes,
    day.lightSleepMinutes
  ];
  if (day.sleepStageSource == null ||
      day.sleepStageSource!.isEmpty ||
      !config.physiology.totalSleepTimeMinutes.contains(total) ||
      !stages.every(config.physiology.sleepStageMinutes.contains)) {
    return false;
  }
  if (stages.any((value) => value! > total!)) return false;
  final coverage =
      stages.fold<double>(0, (sum, value) => sum + value!) / total!;
  return coverage >= config.sleepScore.architecture.minStageCoverage &&
      coverage <= config.sleepScore.architecture.maxStageCoverage;
}

double _adequacyScore(double ratio, AlgorithmConfig config) {
  final anchors = config.sleepScore.adequacyAnchors;
  if (ratio <= anchors.first.ratio) return anchors.first.score;
  for (var index = 1; index < anchors.length; index++) {
    final right = anchors[index];
    if (ratio > right.ratio) continue;
    final left = anchors[index - 1];
    final fraction = (ratio - left.ratio) / (right.ratio - left.ratio);
    return clampDouble(left.score + fraction * (right.score - left.score),
        config.score.min, config.score.max);
  }
  return clampDouble(anchors.last.score, config.score.min, config.score.max);
}

_ComponentScore _calculateCircadianRegularityScore(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  AlgorithmConfig config,
) {
  double? clockMinutes(DateTime? timestamp) => minutesSinceLocalMidnight(
        timestamp,
        profile.timezone,
        config,
      );

  double? meanCircularDeviation(List<double> values) {
    final mean = circularMeanMinutes(values, config);
    if (mean == null) return null;
    return values
            .map((value) =>
                circularAbsoluteDifferenceMinutes(value, mean, config))
            .reduce((sum, value) => sum + value) /
        values.length;
  }

  final todayOnset = clockMinutes(today.sleepOnsetTimestamp);
  if (todayOnset == null) {
    return _ComponentScore(
      value: null,
      warning: 'sleep_onset_today_unavailable_or_invalid_timezone',
      details: {
        'sleepOnsetTimestamp': today.sleepOnsetTimestamp?.toIso8601String(),
        'timezone': profile.timezone,
      },
    );
  }

  final historicalNights = previousDailyHistory(historicalData,
          beforeDate: today.date,
          windowDays: config.sleepScore.circadianWindowDays - 1)
      .where((day) => clockMinutes(day.sleepOnsetTimestamp) != null)
      .toList(growable: false);
  final onsetValues = historicalNights
      .map((day) => clockMinutes(day.sleepOnsetTimestamp))
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList()
    ..add(todayOnset);

  if (onsetValues.length < 2) {
    return _ComponentScore(
      value: null,
      warning: 'sleep_onset_history_unavailable',
      details: {'historicalOnsetCount': onsetValues.length - 1},
    );
  }

  final wakeValues = historicalNights
      .map((day) => clockMinutes(day.sleepWakeTimestamp))
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList();
  final todayWake = clockMinutes(today.sleepWakeTimestamp);
  if (todayWake != null) wakeValues.add(todayWake);

  final historicalOnsetMean = circularMeanMinutes(
      onsetValues.sublist(0, onsetValues.length - 1), config)!;
  final todayOnsetDeviation = circularAbsoluteDifferenceMinutes(
      todayOnset, historicalOnsetMean, config);
  final onsetDeviation =
      math.max(meanCircularDeviation(onsetValues)!, todayOnsetDeviation);
  final historicalWakeValues = todayWake == null
      ? wakeValues
      : wakeValues.sublist(0, wakeValues.length - 1);
  final historicalWakeMean = circularMeanMinutes(historicalWakeValues, config);
  final todayWakeDeviation = todayWake != null && historicalWakeMean != null
      ? circularAbsoluteDifferenceMinutes(todayWake, historicalWakeMean, config)
      : null;
  final wakeDeviation = todayWakeDeviation != null
      ? math.max(meanCircularDeviation(wakeValues)!, todayWakeDeviation)
      : null;
  final deviationMinutes = wakeDeviation == null
      ? onsetDeviation
      : (onsetDeviation + wakeDeviation) / 2;
  final value = clampDouble(
    config.score.max -
        (config.sleepScore.circadianPenaltyPerStep *
            (deviationMinutes - config.sleepScore.circadianToleranceMinutes)
                .clamp(config.score.min, double.infinity) /
            config.sleepScore.circadianPenaltyStepMinutes),
    config.score.min,
    config.score.max,
  );

  return _ComponentScore(
    value: value,
    details: {
      'todayOnsetMinutes': todayOnset,
      'todayWakeMinutes': todayWake,
      'deviationMinutes': deviationMinutes,
      'onsetDeviationMinutes': onsetDeviation,
      'wakeDeviationMinutes': wakeDeviation,
      'todayOnsetDeviationMinutes': todayOnsetDeviation,
      'todayWakeDeviationMinutes': todayWakeDeviation,
      'windowNightCount': onsetValues.length,
      'windowDays': config.sleepScore.circadianWindowDays,
    },
  );
}

_ComponentScore _calculateEfficiencyScore(
  DailyWearableData today,
  AlgorithmConfig config,
) {
  final totalSleep = today.totalSleepTimeMinutes;
  final timeInBed = today.timeInBedMinutes;

  if (!config.physiology.totalSleepTimeMinutes.contains(totalSleep) ||
      !config.physiology.timeInBedMinutes.contains(timeInBed)) {
    return _ComponentScore(
      value: null,
      warning: 'sleep_efficiency_unavailable',
      details: {
        'totalSleepTimeMinutes': totalSleep,
        'timeInBedMinutes': timeInBed,
      },
    );
  }

  if (totalSleep! > timeInBed!) {
    return _ComponentScore(
      value: null,
      warning: 'total_sleep_exceeds_time_in_bed',
      details: {
        'totalSleepTimeMinutes': totalSleep,
        'timeInBedMinutes': timeInBed,
      },
    );
  }

  final efficiencyRatio = totalSleep / timeInBed;
  final scoreableRange =
      config.sleepScore.efficiencyTarget - config.sleepScore.efficiencyFloor;
  if (!scoreableRange.isFinite || scoreableRange <= 0) {
    return _ComponentScore(
      value: null,
      warning: 'invalid_sleep_efficiency_config',
      details: {
        'efficiencyTarget': config.sleepScore.efficiencyTarget,
        'efficiencyFloor': config.sleepScore.efficiencyFloor,
      },
    );
  }

  return _ComponentScore(
    value: clampDouble(
      ((efficiencyRatio - config.sleepScore.efficiencyFloor) / scoreableRange) *
          config.score.max,
      config.score.min,
      config.score.max,
    ),
    details: {
      'totalSleepTimeMinutes': totalSleep,
      'timeInBedMinutes': timeInBed,
      'efficiencyRatio': efficiencyRatio,
      'efficiencyTarget': config.sleepScore.efficiencyTarget,
      'efficiencyFloor': config.sleepScore.efficiencyFloor,
    },
  );
}

Map<String, dynamic> _architectureComponent(
  _ComponentScore architecture,
) {
  return {
    'used': isFiniteNumber(architecture.value),
    'available': isFiniteNumber(architecture.value),
    'informationalOnly': !isFiniteNumber(architecture.value),
    'adjustmentType': 'penalty_points',
    'value': architecture.value,
    'weight': 0.0,
    'effectiveWeight': 0.0,
    if (architecture.warning.isNotEmpty) 'warning': architecture.warning,
    'details': architecture.details,
  };
}

int _maxInt(int a, int b) => a > b ? a : b;

class _ComponentScore {
  final double? value;
  final String warning;
  final Map<String, dynamic> details;

  const _ComponentScore({
    required this.value,
    this.warning = '',
    this.details = const {},
  });
}
