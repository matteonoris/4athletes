import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';
import 'scoring_types.dart';

ScoreResult calculateRecoveryScoreResult(
  AthleteProfile profile,
  DailyWearableData today,
  HistoricalDailyData historicalData,
  ScoreResult todaySleepScore, {
  AlgorithmConfig config = defaultAlgorithmConfig,
}) {
  final canonicalHistory = _canonicalHistory(historicalData, today.date);
  final history = canonicalHistory.takeLast(config.history.rollingWindowDays);
  final warnings = <String>[];
  final adjustedToday = _applyLutealPhaseAdjustment(
    profile,
    today,
    config,
    warnings,
  );
  final hrvMetric = _normalizeHrvMetric(adjustedToday.hrvMetric);
  final temperatureMetric =
      _normalizeTemperatureMetric(adjustedToday.temperatureMetric);
  if (config.physiology.hrvRmssdMs.contains(adjustedToday.hrvRmssdMs) &&
      hrvMetric == 'unknown') {
    warnings.add('hrv_metric_provenance_unknown');
  }
  final validAutonomicHistoryDays = _validAutonomicHistoryDays(
    history,
    hrvMetric,
    config,
  );

  if (validAutonomicHistoryDays < config.history.minCalibrationDays) {
    warnings.add(
      'recovery_calibration_phase_insufficient_valid_autonomic_history',
    );
    return ScoreResult(
      score: null,
      status: ScoreStatus.calibrationPhase,
      confidence: config.confidence.min,
      components: {
        'historyDays': history.length,
        'canonicalHistoryDays': canonicalHistory.length,
        'validAutonomicHistoryDays': validAutonomicHistoryDays,
        'requiredHistoryDays': config.history.minCalibrationDays,
        'hrvMetric': hrvMetric,
        'temperatureMetric': temperatureMetric,
      },
      warnings: uniqueWarnings(warnings),
    );
  }

  if (validAutonomicHistoryDays < config.history.fullCalibrationDays) {
    warnings.add('recovery_partial_autonomic_history');
  }

  final hrv = _calculateHrvComponent(adjustedToday, history, config);
  final restingHeartRate =
      _calculateRestingHeartRateComponent(adjustedToday, history, config);
  final skinTemperature =
      _calculateSkinTemperatureComponent(adjustedToday, history, config);
  final sleep = _calculateAbsoluteSleepComponent(todaySleepScore, config);
  final respiratoryRate =
      _calculateRespiratoryRateComponent(adjustedToday, history, config);
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

  final autonomicComponents =
      [hrv.value, restingHeartRate.value].where(isFiniteNumber).length;
  final historyConfidence = clampDouble(
    validAutonomicHistoryDays / config.history.fullCalibrationDays,
    config.confidence.min,
    config.confidence.max,
  );
  final confidence = clampDouble(
    combined.availableWeight * historyConfidence,
    config.confidence.min,
    config.confidence.max,
  );
  final hasMinimumAutonomic =
      autonomicComponents >= config.recoveryScore.minAutonomicComponents;
  final hasMinimumAvailableWeight = combined.availableWeight + 1e-12 >=
      config.recoveryScore.minAvailableWeight;

  if (!hasMinimumAutonomic) {
    warnings.add('recovery_autonomic_component_required');
  }
  if (!hasMinimumAvailableWeight) {
    warnings.add('recovery_available_weight_below_minimum');
  }

  final baseComponents = <String, dynamic>{
    'historyDays': history.length,
    'canonicalHistoryDays': canonicalHistory.length,
    'validAutonomicHistoryDays': validAutonomicHistoryDays,
    'historyConfidence': historyConfidence,
    'availableWeight': combined.availableWeight,
    'autonomicComponents': autonomicComponents,
    'requiredAutonomicComponents': config.recoveryScore.minAutonomicComponents,
    'requiredAvailableWeight': config.recoveryScore.minAvailableWeight,
    'hrvMetric': hrvMetric,
    'temperatureMetric': temperatureMetric,
    ...combined.components,
  };

  if (combined.value == null ||
      !hasMinimumAutonomic ||
      !hasMinimumAvailableWeight) {
    return ScoreResult(
      score: null,
      status: ScoreStatus.insufficientData,
      confidence: confidence,
      components: baseComponents,
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
  final unique = uniqueWarnings(warnings);
  final hasDegradingWarnings =
      unique.any((warning) => !_isInformationalWarning(warning));
  final fullHistory =
      validAutonomicHistoryDays >= config.history.fullCalibrationDays;
  final fullWeight = combined.availableWeight >= config.confidence.max - 1e-12;

  return ScoreResult(
    score: score,
    status: fullHistory && fullWeight && !hasDegradingWarnings
        ? ScoreStatus.ok
        : ScoreStatus.partialData,
    confidence: confidence,
    components: {
      ...baseComponents,
      'zTotal': zTotal,
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
  final metric = _normalizeHrvMetric(today.hrvMetric);
  if (!config.physiology.hrvRmssdMs.contains(todayHrv)) {
    return _ZComponent(
      value: null,
      warning: 'invalid_hrv',
      details: {
        'todayHrvMs': todayHrv,
        'hrvMetric': metric,
      },
    );
  }

  final historicalLnHrv = history
      .where((day) => _normalizeHrvMetric(day.hrvMetric) == metric)
      .map((day) => day.hrvRmssdMs)
      .where(config.physiology.hrvRmssdMs.contains)
      .map((value) => math.log(value!.toDouble()))
      .toList(growable: false);
  if (historicalLnHrv.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: 'hrv_history_insufficient_for_metric',
      details: {
        'validHistoryDays': historicalLnHrv.length,
        'hrvMetric': metric,
      },
    );
  }

  final stats = medianAndRobustStandardDeviation(
    historicalLnHrv,
    config.zScore.minStdDev.lnHrvRmssd,
  );
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: 'hrv_history_insufficient_for_metric',
      details: {
        'validHistoryDays': historicalLnHrv.length,
        'hrvMetric': metric,
      },
    );
  }

  final lnToday = math.log(todayHrv!);
  final rawZ = clippedZScore(
    value: lnToday,
    mean: stats.median,
    standardDeviation: stats.robustStandardDeviation,
    minStdDev: config.zScore.minStdDev.lnHrvRmssd,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );
  final contribution =
      rawZ == null ? null : _capFavorableContribution(rawZ, config);

  return _ZComponent(
    value: contribution,
    warning: rawZ == null ? 'hrv_z_score_unavailable' : '',
    details: {
      'hrvMetric': metric,
      'todayHrvMs': todayHrv,
      'lnToday': lnToday,
      'medianLnHrv': stats.median,
      'madLnHrv': stats.medianAbsoluteDeviation,
      'robustStdLnHrv': stats.robustStandardDeviation,
      'validHistoryDays': stats.count,
      'rawZScore': rawZ,
      'contribution': contribution,
      'favorableContributionClip':
          config.recoveryScore.favorableContributionClip,
    },
  );
}

_ZComponent _calculateRestingHeartRateComponent(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayValue = today.restingHeartRateBpm;
  final validation = config.physiology.restingHeartRateBpm;
  if (!validation.contains(todayValue)) {
    return _ZComponent(
      value: null,
      warning: 'resting_heart_rate_unavailable',
      details: {'todayValue': todayValue},
    );
  }

  final validHistory = history
      .map((day) => day.restingHeartRateBpm)
      .where(validation.contains)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  return _robustDirectionalComponent(
    key: 'restingHeartRate',
    todayValue: todayValue!,
    validHistory: validHistory,
    minStdDev: config.zScore.minStdDev.restingHeartRateBpm,
    config: config,
  );
}

_ZComponent _calculateSkinTemperatureComponent(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayValue = today.skinTemperatureCelsius;
  final metric = _normalizeTemperatureMetric(today.temperatureMetric);
  if (!_isValidTemperature(todayValue, metric, config)) {
    return _ZComponent(
      value: null,
      warning: 'skin_temperature_unavailable',
      details: {
        'todayValue': todayValue,
        'temperatureMetric': metric,
      },
    );
  }

  final validHistory = history
      .where(
        (day) =>
            _normalizeTemperatureMetric(day.temperatureMetric) == metric &&
            _isValidTemperature(
              day.skinTemperatureCelsius,
              metric,
              config,
            ),
      )
      .map((day) => day.skinTemperatureCelsius!.toDouble())
      .toList(growable: false);
  return _robustAnomalyComponent(
    key: 'skinTemperature',
    todayValue: todayValue!,
    validHistory: validHistory,
    minStdDev: config.zScore.minStdDev.skinTemperatureCelsius,
    anomaly: _Anomaly.highOnly,
    config: config,
    extraDetails: {'temperatureMetric': metric},
  );
}

_ZComponent _calculateRespiratoryRateComponent(
  DailyWearableData today,
  HistoricalDailyData history,
  AlgorithmConfig config,
) {
  final todayValue = today.respiratoryRate;
  final validation = config.physiology.respiratoryRate;
  if (!validation.contains(todayValue)) {
    return _ZComponent(
      value: null,
      warning: 'respiratory_rate_unavailable',
      details: {'todayValue': todayValue},
    );
  }

  final validHistory = history
      .map((day) => day.respiratoryRate)
      .where(validation.contains)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  return _robustAnomalyComponent(
    key: 'respiratoryRate',
    todayValue: todayValue!,
    validHistory: validHistory,
    minStdDev: config.zScore.minStdDev.respiratoryRate,
    anomaly: _Anomaly.twoSided,
    config: config,
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
      .toList(growable: false);
  return _robustAnomalyComponent(
    key: 'spo2',
    todayValue: todayValue!,
    validHistory: validHistory,
    minStdDev: config.zScore.minStdDev.spo2Percent,
    anomaly: _Anomaly.lowOnly,
    config: config,
  );
}

_ZComponent _calculateAbsoluteSleepComponent(
  ScoreResult todaySleepScore,
  AlgorithmConfig config,
) {
  final score = todaySleepScore.score;
  if (!isFiniteNumber(score) ||
      score! < config.score.min ||
      score > config.score.max) {
    return _ZComponent(
      value: null,
      warning: 'today_sleep_score_unavailable',
      details: {'todaySleepScore': score},
    );
  }

  final rawZ = clampDouble(
    (score - config.recoveryScore.sleepNeutralScore) /
        config.recoveryScore.sleepZScale,
    config.zScore.lowerClip,
    config.zScore.upperClip,
  );
  final contribution = _capFavorableContribution(rawZ, config);
  return _ZComponent(
    value: contribution,
    details: {
      'todaySleepScore': score,
      'normalization': 'absolute',
      'neutralSleepScore': config.recoveryScore.sleepNeutralScore,
      'sleepZScale': config.recoveryScore.sleepZScale,
      'rawZScore': rawZ,
      'contribution': contribution,
    },
  );
}

_ZComponent _robustDirectionalComponent({
  required String key,
  required double todayValue,
  required List<double> validHistory,
  required double minStdDev,
  required AlgorithmConfig config,
}) {
  if (validHistory.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }
  final stats = medianAndRobustStandardDeviation(validHistory, minStdDev);
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {'validHistoryDays': validHistory.length},
    );
  }
  final rawZ = clippedZScore(
    value: todayValue,
    mean: stats.median,
    standardDeviation: stats.robustStandardDeviation,
    minStdDev: minStdDev,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );
  final directed = rawZ == null ? null : -rawZ;
  final contribution =
      directed == null ? null : _capFavorableContribution(directed, config);
  return _ZComponent(
    value: contribution,
    warning: rawZ == null ? '${key}_z_score_unavailable' : '',
    details: {
      'todayValue': todayValue,
      'median': stats.median,
      'mad': stats.medianAbsoluteDeviation,
      'robustStandardDeviation': stats.robustStandardDeviation,
      'validHistoryDays': stats.count,
      'rawZScore': rawZ,
      'contribution': contribution,
      'favorableContributionClip':
          config.recoveryScore.favorableContributionClip,
    },
  );
}

_ZComponent _robustAnomalyComponent({
  required String key,
  required double todayValue,
  required List<double> validHistory,
  required double minStdDev,
  required _Anomaly anomaly,
  required AlgorithmConfig config,
  Map<String, dynamic> extraDetails = const {},
}) {
  if (validHistory.length < config.history.minCalibrationDays) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {
        'validHistoryDays': validHistory.length,
        ...extraDetails,
      },
    );
  }
  final stats = medianAndRobustStandardDeviation(validHistory, minStdDev);
  if (stats == null) {
    return _ZComponent(
      value: null,
      warning: '${key}_history_insufficient',
      details: {
        'validHistoryDays': validHistory.length,
        ...extraDetails,
      },
    );
  }
  final rawZ = clippedZScore(
    value: todayValue,
    mean: stats.median,
    standardDeviation: stats.robustStandardDeviation,
    minStdDev: minStdDev,
    lowerClip: config.zScore.lowerClip,
    upperClip: config.zScore.upperClip,
  );
  final contribution = rawZ == null
      ? null
      : switch (anomaly) {
          _Anomaly.highOnly => _highOnlyPenalty(rawZ, config),
          _Anomaly.lowOnly => _lowOnlyPenalty(rawZ, config),
          _Anomaly.twoSided => _twoSidedPenalty(rawZ, config),
        };
  return _ZComponent(
    value: contribution,
    warning: rawZ == null ? '${key}_z_score_unavailable' : '',
    details: {
      'todayValue': todayValue,
      'median': stats.median,
      'mad': stats.medianAbsoluteDeviation,
      'robustStandardDeviation': stats.robustStandardDeviation,
      'validHistoryDays': stats.count,
      'rawZScore': rawZ,
      'deadbandZ': config.recoveryScore.anomalyDeadbandZ,
      'contribution': contribution,
      ...extraDetails,
    },
  );
}

double _capFavorableContribution(double value, AlgorithmConfig config) {
  return clampDouble(
    math.min(value, config.recoveryScore.favorableContributionClip),
    config.zScore.lowerClip,
    config.zScore.upperClip,
  );
}

double _highOnlyPenalty(double rawZ, AlgorithmConfig config) {
  final excess = rawZ - config.recoveryScore.anomalyDeadbandZ;
  if (excess <= 0) return config.confidence.min;
  return clampDouble(-excess, config.zScore.lowerClip, config.confidence.min);
}

double _lowOnlyPenalty(double rawZ, AlgorithmConfig config) {
  final excess = -rawZ - config.recoveryScore.anomalyDeadbandZ;
  if (excess <= 0) return config.confidence.min;
  return clampDouble(-excess, config.zScore.lowerClip, config.confidence.min);
}

double _twoSidedPenalty(double rawZ, AlgorithmConfig config) {
  final excess = rawZ.abs() - config.recoveryScore.anomalyDeadbandZ;
  if (excess <= 0) return config.confidence.min;
  return clampDouble(-excess, config.zScore.lowerClip, config.confidence.min);
}

DailyWearableData _applyLutealPhaseAdjustment(
  AthleteProfile profile,
  DailyWearableData today,
  AlgorithmConfig config,
  List<String> warnings,
) {
  if (!profile.isLutealPhase) return today;
  if (profile.sex != Sex.female) {
    warnings.add('luteal_phase_context_ignored_for_profile_sex');
    return today;
  }
  if (!config.recoveryScore.lutealPhaseAdjustment.enabled) {
    warnings.add('luteal_phase_context_only_fixed_adjustment_disabled');
    return today;
  }

  warnings.add('luteal_phase_fixed_adjustment_applied');
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

List<DailyWearableData> _canonicalHistory(
  HistoricalDailyData historicalData,
  String todayDate,
) {
  final byDate = <String, DailyWearableData>{};
  for (final day in historicalData) {
    if (day.date.isEmpty || day.date == todayDate) continue;
    byDate[day.date] = day;
  }
  final history = byDate.values.toList(growable: false);
  history.sort((a, b) => a.date.compareTo(b.date));
  return history;
}

int _validAutonomicHistoryDays(
  HistoricalDailyData history,
  String todayHrvMetric,
  AlgorithmConfig config,
) {
  return history.where((day) {
    final validRhr =
        config.physiology.restingHeartRateBpm.contains(day.restingHeartRateBpm);
    final validHrv = _normalizeHrvMetric(day.hrvMetric) == todayHrvMetric &&
        config.physiology.hrvRmssdMs.contains(day.hrvRmssdMs);
    return validRhr || validHrv;
  }).length;
}

bool _isValidTemperature(
  num? value,
  String metric,
  AlgorithmConfig config,
) {
  if (!isFiniteNumber(value)) return false;
  if (metric == 'skin_temperature_delta_celsius') {
    return value! >= -10 && value <= 10;
  }
  return config.physiology.skinTemperatureCelsius.contains(value);
}

String _normalizeHrvMetric(String metric) {
  final normalized = metric.trim().toLowerCase().replaceAll('-', '_');
  if (normalized.contains('rmssd')) return 'rmssd';
  if (normalized.contains('sdnn')) return 'sdnn';
  return normalized.isEmpty ? 'unknown' : normalized;
}

String _normalizeTemperatureMetric(String metric) {
  final normalized = metric.trim().toLowerCase().replaceAll('-', '_');
  if (normalized.contains('delta')) return 'skin_temperature_delta_celsius';
  if (normalized.contains('wrist')) return 'wrist_temperature_celsius';
  if (normalized.contains('skin')) return 'skin_temperature_celsius';
  if (normalized.contains('body')) return 'body_temperature_celsius';
  return normalized.isEmpty ? 'unknown' : normalized;
}

bool _isInformationalWarning(String warning) {
  return warning == 'luteal_phase_context_only_fixed_adjustment_disabled';
}

enum _Anomaly { highOnly, lowOnly, twoSided }

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
