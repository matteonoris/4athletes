import 'package:health/health.dart';

import '../models/models.dart';

/// Converts provider samples to the units stored by 4athletes before averaging.
/// Apple HKUnit.percent uses 0...1; Health Connect uses percentage points.
class DailyHealthMetricNormalizer {
  static const units = <HealthDataType, HealthDataUnit>{
    HealthDataType.RESTING_HEART_RATE: HealthDataUnit.BEATS_PER_MINUTE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: HealthDataUnit.MILLISECOND,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: HealthDataUnit.MILLISECOND,
    HealthDataType.WEIGHT: HealthDataUnit.KILOGRAM,
    HealthDataType.BLOOD_OXYGEN: HealthDataUnit.PERCENT,
    HealthDataType.RESPIRATORY_RATE: HealthDataUnit.RESPIRATIONS_PER_MINUTE,
    HealthDataType.SLEEP_WRIST_TEMPERATURE: HealthDataUnit.DEGREE_CELSIUS,
    HealthDataType.SKIN_TEMPERATURE: HealthDataUnit.DEGREE_CELSIUS,
  };

  static const _keys = <HealthDataType, String>{
    HealthDataType.RESTING_HEART_RATE: 'resting_hr',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv_sdnn',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'hrv_rmssd',
    HealthDataType.WEIGHT: 'weight',
    HealthDataType.BLOOD_OXYGEN: 'spo2',
    HealthDataType.RESPIRATORY_RATE: 'resp',
    HealthDataType.SLEEP_WRIST_TEMPERATURE: 'wrist_temp_c',
    HealthDataType.SKIN_TEMPERATURE: 'skin_temp_delta_c',
  };

  static double? value(HealthDataPoint point) {
    final raw = point.value;
    double number;
    if (point.type == HealthDataType.SKIN_TEMPERATURE &&
        raw is SkinTemperatureHealthValue) {
      number = raw.temperatureDelta;
    } else if (raw is NumericHealthValue) {
      number = raw.numericValue.toDouble();
    } else {
      return null;
    }
    if (!number.isFinite || !units.containsKey(point.type)) return null;

    // Request canonical units at the plugin boundary, but also handle explicit
    // alternate units so imported fixtures/providers cannot silently mix scales.
    switch (point.type) {
      case HealthDataType.BLOOD_OXYGEN:
        if (point.unit != HealthDataUnit.PERCENT) return null;
        if (point.sourcePlatform == HealthPlatformType.appleHealth) {
          if (number < 0 || number > 1) return null;
          number *= 100;
        }
        return number >= 0 && number <= 100 ? number : null;
      case HealthDataType.WEIGHT:
        number = switch (point.unit) {
          HealthDataUnit.KILOGRAM => number,
          HealthDataUnit.GRAM => number / 1000,
          HealthDataUnit.POUND => number * 0.45359237,
          HealthDataUnit.OUNCE => number * 0.028349523125,
          HealthDataUnit.STONE => number * 6.35029318,
          _ => double.nan,
        };
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
      case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        number = switch (point.unit) {
          HealthDataUnit.MILLISECOND => number,
          HealthDataUnit.SECOND => number * 1000,
          _ => double.nan,
        };
      case HealthDataType.SLEEP_WRIST_TEMPERATURE:
      case HealthDataType.SKIN_TEMPERATURE:
        final isDelta = point.type == HealthDataType.SKIN_TEMPERATURE;
        number = switch (point.unit) {
          HealthDataUnit.DEGREE_CELSIUS => number,
          HealthDataUnit.DEGREE_FAHRENHEIT =>
            isDelta ? number / 1.8 : (number - 32) / 1.8,
          HealthDataUnit.KELVIN => isDelta ? number : number - 273.15,
          _ => double.nan,
        };
        return number.isFinite ? number : null;
      default:
        if (point.unit != units[point.type]) return null;
    }
    return number.isFinite && number > 0 ? number : null;
  }

  static Map<String, List<BodyMetricLog>> aggregate(
    Iterable<HealthDataPoint> points,
  ) {
    final dailyValues = <String, Map<String, List<double>>>{
      for (final key in _keys.values) key: {},
    };
    final seen = <Object>{};
    for (final point in points) {
      final key = _keys[point.type];
      final normalized = value(point);
      if (key == null || normalized == null) continue;
      // Preserve distinct observations, including multiple temperature deltas
      // in one Health Connect record, while ignoring repeated native samples.
      if (point.uuid.isNotEmpty &&
          !seen.add((
            point.sourcePlatform,
            point.uuid,
            point.type,
            point.dateFrom,
            point.dateTo
          ))) {
        continue;
      }
      final time = (point.type == HealthDataType.SLEEP_WRIST_TEMPERATURE
              ? point.dateTo
              : point.dateFrom)
          .toLocal();
      if ((key == 'hrv_sdnn' || key == 'hrv_rmssd') && time.hour >= 8) {
        continue; // Recovery HRV uses the local 00:00 <= time < 08:00 window.
      }
      final date = time.toIso8601String().split('T').first;
      dailyValues[key]!.putIfAbsent(date, () => []).add(normalized);
    }
    return dailyValues.map((key, days) {
      final logs = days.entries.map((entry) {
        final samples = entry.value;
        return BodyMetricLog(
          id: '${key}_${entry.key}',
          date: entry.key,
          type: key,
          value: samples.reduce((a, b) => a + b) / samples.length,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return MapEntry(key, logs);
    });
  }

  /// Re-read suspicious historical oxygen days from HealthKit, rather than
  /// guessing the scale of stored rows that have no source/unit metadata.
  static DateTime? oxygenHistoryStart(Iterable<BodyMetricLog> logs) {
    DateTime? earliest;
    for (final log in logs) {
      if (log.type != 'spo2' ||
          !log.value.isFinite ||
          log.value <= 0 ||
          log.value > 1) {
        continue;
      }
      final date = DateTime.tryParse(log.date);
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    return earliest;
  }
}
