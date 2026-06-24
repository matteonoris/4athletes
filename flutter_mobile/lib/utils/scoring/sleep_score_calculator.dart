import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';
import 'time_helpers.dart';

ScoreResult calculateSleepScoreResult(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  DailySleepNeedResult dailySleepNeed, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final history =
      historicalData.where((day) => day.date != today.date).toList();
  final warnings = <String>[...dailySleepNeed.warnings];

  if (history.length < config.history.minCalibrationDays) {
    warnings.add('sleep_score_provisional_less_than_4_history_days');
  } else if (history.length < config.history.rollingWindowDays) {
    warnings.add('sleep_score_partial_history_less_than_30_days');
  }

  final duration = _calculateDurationScore(today, dailySleepNeed, config);
  final architecture = _calculateArchitectureScore(today, config);
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
        key: 'architecture',
        value: architecture.value,
        weight: config.sleepScore.weights.architecture,
        warning: architecture.warning,
        details: architecture.details,
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

  if (combined.value == null) {
    return ScoreResult(
      score: null,
      status: ScoreStatus.insufficientData,
      confidence: config.confidence.min,
      components: {
        'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
        'availableWeight': combined.availableWeight,
        ...combined.components,
      },
      warnings: uniqueWarnings(warnings),
    );
  }

  var confidence = combined.availableWeight * dailySleepNeed.confidence;
  if (history.length < config.history.minCalibrationDays) {
    confidence *= config.confidence.fallbackSleepBaselineMultiplier;
  } else if (history.length < config.history.rollingWindowDays) {
    confidence *= config.confidence.shortHistoryMultiplier;
  }

  final unique = uniqueWarnings(warnings);
  return ScoreResult(
    score: clampDouble(combined.value!, config.score.min, config.score.max),
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
  final totalSleep = today.totalSleepTimeMinutes;
  if (!config.physiology.totalSleepTimeMinutes.contains(totalSleep)) {
    return _ComponentScore(
      value: null,
      warning: 'invalid_or_missing_total_sleep_time',
      details: {
        'totalSleepTimeMinutes': totalSleep,
        'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
      },
    );
  }

  return _ComponentScore(
    value: clampDouble(
      (totalSleep! / dailySleepNeed.valueMinutes) * config.score.max,
      config.score.min,
      config.score.max,
    ),
    details: {
      'totalSleepTimeMinutes': totalSleep,
      'dailySleepNeedMinutes': dailySleepNeed.valueMinutes,
    },
  );
}

_ComponentScore _calculateArchitectureScore(
  DailyWearableData today,
  AlgorithmConfig config,
) {
  final totalSleep = today.totalSleepTimeMinutes;
  final deepSleep = today.deepSleepMinutes;
  final remSleep = today.remSleepMinutes;

  if (!config.physiology.totalSleepTimeMinutes.contains(totalSleep) ||
      !isFiniteNumber(deepSleep) ||
      !isFiniteNumber(remSleep)) {
    return _ComponentScore(
      value: null,
      warning: 'sleep_architecture_unavailable',
      details: {
        'deepSleepMinutes': deepSleep,
        'remSleepMinutes': remSleep,
      },
    );
  }

  if (!config.physiology.sleepStageMinutes.contains(deepSleep) ||
      !config.physiology.sleepStageMinutes.contains(remSleep) ||
      deepSleep! + remSleep! > totalSleep!) {
    return _ComponentScore(
      value: null,
      warning: 'sleep_architecture_invalid',
      details: {
        'totalSleepTimeMinutes': totalSleep,
        'deepSleepMinutes': deepSleep,
        'remSleepMinutes': remSleep,
      },
    );
  }

  final restorativeRatio = (deepSleep + remSleep) / totalSleep;
  final value = restorativeRatio >= config.sleepScore.restorativeRatioTarget
      ? config.score.max
      : clampDouble(
          (restorativeRatio / config.sleepScore.restorativeRatioTarget) *
              config.score.max,
          config.score.min,
          config.score.max,
        );

  return _ComponentScore(
    value: value,
    details: {
      'restorativeRatio': restorativeRatio,
      'deepSleepMinutes': deepSleep,
      'remSleepMinutes': remSleep,
    },
  );
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

  final historicalNights = historicalData
      .where((day) => clockMinutes(day.sleepOnsetTimestamp) != null)
      .toList(growable: false)
      .takeLast(config.sleepScore.circadianWindowDays - 1);
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

  final onsetDeviation = meanCircularDeviation(onsetValues)!;
  final wakeDeviation =
      wakeValues.length >= 2 ? meanCircularDeviation(wakeValues) : null;
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

  return _ComponentScore(
    value: clampDouble(
      (totalSleep / timeInBed) * config.score.max,
      config.score.min,
      config.score.max,
    ),
    details: {
      'totalSleepTimeMinutes': totalSleep,
      'timeInBedMinutes': timeInBed,
    },
  );
}

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

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return const [];
    if (length <= count) return List<T>.from(this);
    return sublist(length - count);
  }
}
