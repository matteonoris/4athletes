import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';
import 'sleep_need_calculator.dart';
import 'sleep_score_calculator.dart';

ScoreResult calculateRecoveryScoreResult(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  ScoreResult todaySleepScore, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final history =
      historicalData.where((day) => day.date != today.date).toList();
  final warnings = <String>[];

  if (history.length < config.history.minCalibrationDays) {
    return ScoreResult(
      score: null,
      status: ScoreStatus.calibrationPhase,
      confidence: config.confidence.min,
      components: {
        'historyDays': history.length,
        'requiredHistoryDays': config.history.minCalibrationDays,
      },
      warnings: const ['recovery_calibration_phase_less_than_4_history_days'],
    );
  }

  if (history.length < config.history.rollingWindowDays) {
    warnings.add('recovery_partial_history_less_than_30_days');
  }

  final adjustedToday = _applyLutealPhaseAdjustment(
    profile,
    today,
    config,
    warnings,
  );
  final hrv = _calculateHrvComponent(adjustedToday, history, config);
  final restingHeartRate = _calculateInverseMetricComponent(
    key: 'restingHeartRate',
    todayValue: adjustedToday.restingHeartRateBpm,
    historyValues: history.map((day) => day.restingHeartRateBpm).toList(),
    validation: config.physiology.restingHeartRateBpm,
    minStdDev: config.zScore.minStdDev.restingHeartRateBpm,
    missingWarning: 'resting_heart_rate_unavailable',
    config: config,
  );
  final skinTemperature =
      _calculateSkinTemperatureComponent(adjustedToday, history, config);
  final sleep = _calculateSleepComponent(
    profile,
    today,
    history,
    todaySleepScore,
    config,
  );
  final respiratoryRate = _calculateInverseMetricComponent(
    key: 'respiratoryRate',
    todayValue: adjustedToday.respiratoryRate,
    historyValues: history.map((day) => day.respiratoryRate).toList(),
    validation: config.physiology.respiratoryRate,
    minStdDev: config.zScore.minStdDev.respiratoryRate,
    missingWarning: 'respiratory_rate_unavailable',
    config: config,
  );
  final spo2 = _calculateSpo2Component(adjustedToday, history, config);

  final combined = combineWeightedValues(
    [
      WeightedValue(
        key: 'hrv',
        value: hrv.value,
        weight: config.recoveryScore.weights.hrv,
        warning: hrv.warning,
        details: hrv.details,
      ),
      WeightedValue(
        key: 'restingHeartRate',
        value: restingHeartRate.value,
        weight: config.recoveryScore.weights.restingHeartRate,
        warning: restingHeartRate.warning,
        details: restingHeartRate.details,
      ),
      WeightedValue(
        key: 'skinTemperature',
        value: skinTemperature.value,
        weight: config.recoveryScore.weights.skinTemperature,
        warning: skinTemperature.warning,
        details: skinTemperature.details,
      ),
      WeightedValue(
        key: 'sleep',
        value: sleep.value,
        weight: config.recoveryScore.weights.sleep,
        warning: sleep.warning,
        details: sleep.details,
      ),
      WeightedValue(
        key: 'respiratoryRate',
        value: respiratoryRate.value,
        weight: config.recoveryScore.weights.respiratoryRate,
        warning: respiratoryRate.warning,
        details: respiratoryRate.details,
      ),
      WeightedValue(
        key: 'spo2',
        value: spo2.value,
        weight: config.recoveryScore.weights.spo2,
        warning: spo2.warning,
        details: spo2.details,
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
        'historyDays': history.length,
        'availableWeight': combined.availableWeight,
        ...combined.components,
      },
      warnings: uniqueWarnings(warnings),
    );
  }

  final zTotal = clampDouble(
    combined.value!,
    config.zScore.lowerClip,
    config.zScore.upperClip,
  );
  final score = clampDouble(
    sigmoid(
          zTotal + config.recoveryScore.sigmoidBias,
          config.recoveryScore.sigmoidK,
        ) *
        config.score.max,
    config.score.min,
    config.score.max,
  );
  final confidence = clampDouble(
    combined.availableWeight *
        (history.length < config.history.rollingWindowDays
            ? config.confidence.shortHistoryMultiplier
            : config.confidence.max),
    config.confidence.min,
    config.confidence.max,
  );
  final unique = uniqueWarnings(warnings);

  return ScoreResult(
    score: score,
    status: unique.isEmpty && combined.availableWeight >= config.confidence.max
        ? ScoreStatus.ok
        : ScoreStatus.partialData,
    confidence: confidence,
    components: {
      'historyDays': history.length,
      'availableWeight': combined.availableWeight,
      'zTotal': zTotal,
      ...combined.components,
    },
    warnings: unique,
  );
}

_ZComponent _calculateHrvComponent(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayHrv = today.hrvRmssdMs;
  if (!config.physiology.hrvRmssdMs.contains(todayHrv)) {
    return _ZComponent(
      value: null,
      warning: 'invalid_hrv_rmssd',
      details: {'todayHrvRmssdMs': todayHrv},
    );
  }

  final historicalLnHrv = history
      .map((day) => day.hrvRmssdMs)
      .where(config.physiology.hrvRmssdMs.contains)
      .map((value) => math.log(value!.toDouble()))
      .toList()
      .takeLast(config.history.rollingWindowDays);

  if (historicalLnHrv.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: 'hrv_history_insufficient',
      details: {'validHistoryDays': historicalLnHrv.length},
    );
  }

  final stats = meanAndSafeStandardDeviation(
    historicalLnHrv,
    config.zScore.minStdDev.lnHrvRmssd,
  );
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: 'hrv_history_insufficient',
      details: {'validHistoryDays': historicalLnHrv.length},
    );
  }

  final lnToday = math.log(todayHrv!);
  final z = clippedZScore(
    value: lnToday,
    mean: stats.mean,
    standardDeviation: stats.standardDeviation,
    minStdDev: config.zScore.minStdDev.lnHrvRmssd,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );

  return _ZComponent(
    value: z,
    warning: z == null ? 'hrv_z_score_unavailable' : '',
    details: {
      'lnToday': lnToday,
      'meanLnHrv': stats.mean,
      'stdLnHrv': stats.standardDeviation,
      'validHistoryDays': stats.count,
      'contribution': z,
    },
  );
}

_ZComponent _calculateInverseMetricComponent({
  required String key,
  required double? todayValue,
  required List<num?> historyValues,
  required MetricRange validation,
  required double minStdDev,
  required String missingWarning,
  required AlgorithmConfig config,
}) {
  if (!validation.contains(todayValue)) {
    return _ZComponent(
      value: null,
      warning: missingWarning,
      details: {'todayValue': todayValue},
    );
  }

  final validHistory = historyValues
      .where(validation.contains)
      .map((value) => value!.toDouble())
      .toList()
      .takeLast(config.history.rollingWindowDays);
  if (validHistory.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final stats = meanAndSafeStandardDeviation(validHistory, minStdDev);
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final z = clippedZScore(
    value: todayValue!,
    mean: stats.mean,
    standardDeviation: stats.standardDeviation,
    minStdDev: minStdDev,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );

  return _ZComponent(
    value: z == null ? null : -z,
    warning: z == null ? '${key}_z_score_unavailable' : '',
    details: {
      'todayValue': todayValue,
      'mean': stats.mean,
      'standardDeviation': stats.standardDeviation,
      'validHistoryDays': stats.count,
      'zScore': z,
      'contribution': z == null ? null : -z,
    },
  );
}

_ZComponent _calculateSkinTemperatureComponent(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayValue = today.skinTemperatureCelsius;
  final validation = config.physiology.skinTemperatureCelsius;
  if (!validation.contains(todayValue)) {
    return _ZComponent(
      value: null,
      warning: 'skin_temperature_unavailable',
      details: {'todayValue': todayValue},
    );
  }

  final validHistory = history
      .map((day) => day.skinTemperatureCelsius)
      .where(validation.contains)
      .map((value) => value!.toDouble())
      .toList()
      .takeLast(config.history.rollingWindowDays);
  if (validHistory.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: 'skin_temperature_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final stats = meanAndSafeStandardDeviation(
    validHistory,
    config.zScore.minStdDev.skinTemperatureCelsius,
  );
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: 'skin_temperature_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final z = clippedZScore(
    value: todayValue!,
    mean: stats.mean,
    standardDeviation: stats.standardDeviation,
    minStdDev: config.zScore.minStdDev.skinTemperatureCelsius,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );
  final contribution =
      z == null ? null : (z > config.score.min ? -z : config.score.min);

  return _ZComponent(
    value: contribution,
    warning: z == null ? 'skin_temperature_z_score_unavailable' : '',
    details: {
      'todayValue': todayValue,
      'mean': stats.mean,
      'standardDeviation': stats.standardDeviation,
      'validHistoryDays': stats.count,
      'zScore': z,
      'contribution': contribution,
    },
  );
}

_ZComponent _calculateSpo2Component(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayValue = today.spo2Percent;
  final validation = config.physiology.spo2Percent;
  if (!validation.contains(todayValue)) {
    return _ZComponent(
      value: null,
      warning: 'spo2_unavailable',
      details: {'todayValue': todayValue},
    );
  }

  final validHistory = history
      .map((day) => day.spo2Percent)
      .where(validation.contains)
      .map((value) => value!.toDouble())
      .toList()
      .takeLast(config.history.rollingWindowDays);
  if (validHistory.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: 'spo2_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final stats = meanAndSafeStandardDeviation(
    validHistory,
    config.zScore.minStdDev.spo2Percent,
  );
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: 'spo2_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }

  final z = clippedZScore(
    value: todayValue!,
    mean: stats.mean,
    standardDeviation: stats.standardDeviation,
    minStdDev: config.zScore.minStdDev.spo2Percent,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );
  final contribution =
      z == null ? null : (z < config.score.min ? z : config.score.min);

  return _ZComponent(
    value: contribution,
    warning: z == null ? 'spo2_z_score_unavailable' : '',
    details: {
      'todayValue': todayValue,
      'mean': stats.mean,
      'standardDeviation': stats.standardDeviation,
      'validHistoryDays': stats.count,
      'zScore': z,
      'contribution': contribution,
    },
  );
}

_ZComponent _calculateSleepComponent(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData history,
  ScoreResult todaySleepScore,
  AlgorithmConfig config,
) {
  if (!isFiniteNumber(todaySleepScore.score)) {
    return _ZComponent(
      value: null,
      warning: 'today_sleep_score_unavailable',
      details: {'todaySleepScore': todaySleepScore.score},
    );
  }

  final historicalScores = <double>[];
  for (var index = 0; index < history.length; index++) {
    final historicalDay = history[index];
    final historyBeforeDay = history.sublist(0, index);
    final need = calculateDailySleepNeed(
      historicalDay,
      historyBeforeDay,
      config: config,
    );
    final score = calculateSleepScoreResult(
      profile,
      historicalDay,
      historyBeforeDay,
      need,
      config: config,
    ).score;
    if (isFiniteNumber(score)) historicalScores.add(score!);
  }

  final baselineScores =
      historicalScores.takeLast(config.history.rollingWindowDays);
  if (baselineScores.length >= config.history.sleepScoreBaselineMinDays) {
    final stats = meanAndSafeStandardDeviation(
      baselineScores,
      config.zScore.minStdDev.sleepScore,
    );
    if (stats != null) {
      final z = clippedZScore(
        value: todaySleepScore.score!,
        mean: stats.mean,
        standardDeviation: stats.standardDeviation,
        minStdDev: config.zScore.minStdDev.sleepScore,
        lowerClip: config.zScore.lowerClip,
        upperClip: config.zScore.upperClip,
      );
      return _ZComponent(
        value: z,
        warning: z == null ? 'sleep_score_z_score_unavailable' : '',
        details: {
          'todaySleepScore': todaySleepScore.score,
          'meanSleepScore': stats.mean,
          'standardDeviation': stats.standardDeviation,
          'validHistoryDays': stats.count,
          'contribution': z,
        },
      );
    }
  }

  final fallbackZ = clampDouble(
    ((todaySleepScore.score! - config.score.neutralRecoveryScore) /
            config.score.fallbackSleepScoreRange) *
        config.score.fallbackSleepZScale,
    config.zScore.lowerClip,
    config.zScore.upperClip,
  );

  return _ZComponent(
    value: fallbackZ,
    warning: 'sleep_score_baseline_unavailable_fallback_used',
    details: {
      'todaySleepScore': todaySleepScore.score,
      'contribution': fallbackZ,
    },
  );
}

DailyWearableData _applyLutealPhaseAdjustment(
  AthleteProfile profile,
  DailyWearableData today,
  AlgorithmConfig config,
  List<String> warnings,
) {
  if (!profile.isLutealPhase) return today;

  if (profile.sex != Sex.female) {
    warnings.add('luteal_phase_adjustment_ignored_for_profile_sex');
    return today;
  }

  warnings.add('luteal_phase_adjustment_applied');
  return today.copyWith(
    restingHeartRateBpm: isFiniteNumber(today.restingHeartRateBpm)
        ? today.restingHeartRateBpm! -
            config
                .recoveryScore.lutealPhaseAdjustment.restingHeartRateSubtractBpm
        : today.restingHeartRateBpm,
    skinTemperatureCelsius: isFiniteNumber(today.skinTemperatureCelsius)
        ? today.skinTemperatureCelsius! -
            config.recoveryScore.lutealPhaseAdjustment
                .skinTemperatureSubtractCelsius
        : today.skinTemperatureCelsius,
    hrvRmssdMs: isFiniteNumber(today.hrvRmssdMs)
        ? today.hrvRmssdMs! *
            config.recoveryScore.lutealPhaseAdjustment.hrvMultiplier
        : today.hrvRmssdMs,
  );
}

class _ZComponent {
  final double? value;
  final String warning;
  final Map<String, dynamic> details;

  const _ZComponent({
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
