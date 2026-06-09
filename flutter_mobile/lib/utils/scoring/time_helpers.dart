import 'dart:math' as math;

import 'algorithm_config.dart';
import 'math_helpers.dart';

double? minutesSinceLocalMidnight(
  DateTime? timestamp,
  String timezone,
  AlgorithmConfig config,
) {
  if (timestamp == null || timezone.trim().isEmpty) return null;

  // Apple Health and Health Connect provide DateTime values already anchored to
  // the device/athlete local timeline. Dart core has no IANA timezone database,
  // so backend adapters should pass timestamps already resolved for timezone.
  final localTimestamp = timestamp.isUtc ? timestamp.toLocal() : timestamp;
  return (localTimestamp.hour * config.time.minutesPerHour +
          localTimestamp.minute)
      .toDouble();
}

double? circularMeanMinutes(List<num?> values, AlgorithmConfig config) {
  final valid = values
      .where(isFiniteNumber)
      .map((value) => value!.toDouble())
      .where((value) => value >= 0 && value < config.time.minutesPerDay)
      .toList(growable: false);
  if (valid.isEmpty) return null;

  final radiansPerMinute = (math.pi * 2) / config.time.minutesPerDay;
  final sinSum = valid.fold<double>(
    0,
    (sum, value) => sum + math.sin(value * radiansPerMinute),
  );
  final cosSum = valid.fold<double>(
    0,
    (sum, value) => sum + math.cos(value * radiansPerMinute),
  );
  if (math.sqrt(sinSum * sinSum + cosSum * cosSum) <= double.minPositive) {
    return null;
  }

  final angle = math.atan2(sinSum / valid.length, cosSum / valid.length);
  final normalizedAngle = angle < 0 ? angle + math.pi * 2 : angle;
  return (normalizedAngle / radiansPerMinute) % config.time.minutesPerDay;
}

double circularAbsoluteDifferenceMinutes(
  double a,
  double b,
  AlgorithmConfig config,
) {
  final rawDifference = (a - b).abs() % config.time.minutesPerDay;
  return math.min(rawDifference, config.time.minutesPerDay - rawDifference);
}
