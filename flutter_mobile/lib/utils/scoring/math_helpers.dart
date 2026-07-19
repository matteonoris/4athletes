import 'dart:math' as math;

import 'algorithm_config.dart';

class Stats {
  final double mean;
  final double standardDeviation;
  final int count;

  const Stats({
    required this.mean,
    required this.standardDeviation,
    required this.count,
  });
}

class RobustStats {
  final double median;
  final double medianAbsoluteDeviation;
  final double robustStandardDeviation;
  final int count;

  const RobustStats({
    required this.median,
    required this.medianAbsoluteDeviation,
    required this.robustStandardDeviation,
    required this.count,
  });
}

class WeightedValue {
  final String key;
  final double? value;
  final double weight;
  final String warning;
  final Map<String, dynamic> details;

  const WeightedValue({
    required this.key,
    required this.value,
    required this.weight,
    required this.warning,
    this.details = const {},
  });
}

class WeightedCombination {
  final double? value;
  final double availableWeight;
  final Map<String, dynamic> components;
  final List<String> warnings;

  const WeightedCombination({
    required this.value,
    required this.availableWeight,
    required this.components,
    required this.warnings,
  });
}

bool isFiniteNumber(num? value) => value != null && value.isFinite;

double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double? rollingMean(List<num?> values, int windowSize) {
  final window = _lastFiniteValues(values, windowSize);
  if (window.isEmpty) return null;
  return window.reduce((a, b) => a + b) / window.length;
}

double? rollingStandardDeviation(
  List<num?> values,
  int windowSize,
  double minStdDev,
) {
  return safeStandardDeviation(
      _lastFiniteValues(values, windowSize), minStdDev);
}

double? safeStandardDeviation(List<num?> values, double minStdDev) {
  final finite = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  if (finite.isEmpty || !minStdDev.isFinite || minStdDev <= 0) return null;

  final mean = finite.reduce((a, b) => a + b) / finite.length;
  final variance =
      finite.map((value) => math.pow(value - mean, 2).toDouble()).reduce(
                (a, b) => a + b,
              ) /
          finite.length;
  return math.max(math.sqrt(variance), minStdDev);
}

double? percentile(List<num?> values, double percentile) {
  final finite = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList(growable: false)
    ..sort();
  if (finite.isEmpty || !percentile.isFinite) return null;
  final clamped = clampDouble(percentile, 0, 1);
  if (finite.length == 1) return finite.first;

  final rank = clamped * (finite.length - 1);
  final lower = rank.floor();
  final upper = rank.ceil();
  if (lower == upper) return finite[lower];

  final fraction = rank - lower;
  return finite[lower] + (finite[upper] - finite[lower]) * fraction;
}

double? median(List<num?> values) => percentile(values, 0.5);

/// Returns robust location and scale estimates.
///
/// The raw median absolute deviation is multiplied by 1.4826 so the resulting
/// scale is comparable with a standard deviation for approximately normal
/// data. A metric-specific floor keeps a stable personal baseline from
/// amplifying measurement noise into a large readiness swing.
RobustStats? medianAndRobustStandardDeviation(
  List<num?> values,
  double minStandardDeviation,
) {
  final finite = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  if (finite.isEmpty ||
      !minStandardDeviation.isFinite ||
      minStandardDeviation <= 0) {
    return null;
  }

  final center = median(finite);
  if (center == null) return null;
  final absoluteDeviations =
      finite.map((value) => (value - center).abs()).toList(growable: false);
  final rawMad = median(absoluteDeviations);
  if (rawMad == null) return null;

  return RobustStats(
    median: center,
    medianAbsoluteDeviation: rawMad,
    robustStandardDeviation: math.max(rawMad * 1.4826, minStandardDeviation),
    count: finite.length,
  );
}

double? zScore({
  required double value,
  required double mean,
  required double standardDeviation,
  required double minStdDev,
}) {
  if (!value.isFinite ||
      !mean.isFinite ||
      !standardDeviation.isFinite ||
      !minStdDev.isFinite ||
      minStdDev <= 0) {
    return null;
  }

  final denominator = math.max(standardDeviation.abs(), minStdDev);
  return (value - mean) / denominator;
}

double? clippedZScore({
  required double value,
  required double mean,
  required double standardDeviation,
  required double minStdDev,
  required double lowerClip,
  required double upperClip,
}) {
  final raw = zScore(
    value: value,
    mean: mean,
    standardDeviation: standardDeviation,
    minStdDev: minStdDev,
  );
  if (raw == null) return null;
  return clampDouble(raw, lowerClip, upperClip);
}

Stats? meanAndSafeStandardDeviation(List<num?> values, double minStdDev) {
  final finite = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  if (finite.isEmpty) return null;

  final mean = finite.reduce((a, b) => a + b) / finite.length;
  final standardDeviation = safeStandardDeviation(finite, minStdDev);
  if (standardDeviation == null) return null;

  return Stats(
    mean: mean,
    standardDeviation: standardDeviation,
    count: finite.length,
  );
}

WeightedCombination combineWeightedValues(
  List<WeightedValue> values,
  AlgorithmConfig config,
) {
  final available =
      values.where((component) => isFiniteNumber(component.value)).toList();
  final availableWeight =
      available.fold<double>(config.confidence.min, (sum, item) {
    return sum + item.weight;
  });
  final warnings = values
      .where((component) => !isFiniteNumber(component.value))
      .map((component) => component.warning)
      .where((warning) => warning.isNotEmpty)
      .toList(growable: false);

  final components = <String, dynamic>{};
  for (final component in values) {
    final used = isFiniteNumber(component.value);
    final effectiveWeight = used && availableWeight > config.confidence.min
        ? component.weight / availableWeight
        : config.confidence.min;
    components[component.key] = {
      'used': used,
      'value': component.value,
      'weight': component.weight,
      'effectiveWeight': effectiveWeight,
      if (!used) 'warning': component.warning,
      'details': component.details,
    };
  }

  if (available.isEmpty || availableWeight <= config.confidence.min) {
    return WeightedCombination(
      value: null,
      availableWeight: config.confidence.min,
      components: components,
      warnings: warnings,
    );
  }

  final weightedSum =
      available.fold<double>(config.confidence.min, (sum, item) {
    return sum + item.value! * item.weight;
  });

  // Missing components are excluded and available weights are renormalized.
  // Confidence is reduced separately by availableWeight, so missing wearable
  // streams never become silent neutral values.
  return WeightedCombination(
    value: weightedSum / availableWeight,
    availableWeight: availableWeight,
    components: components,
    warnings: warnings,
  );
}

double sigmoid(double value, double k) {
  return 1 / (1 + math.exp(-k * value));
}

List<String> uniqueWarnings(Iterable<String> warnings) {
  return warnings.where((warning) => warning.isNotEmpty).toSet().toList();
}

List<double> _lastFiniteValues(List<num?> values, int windowSize) {
  if (windowSize <= 0) return const [];
  final finite = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .toList(growable: false);
  if (finite.length <= windowSize) return finite;
  return finite.sublist(finite.length - windowSize);
}
