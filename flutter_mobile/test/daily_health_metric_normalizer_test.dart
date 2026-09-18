import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/services/daily_health_metric_normalizer.dart';
import 'package:flutter_mobile/utils/health_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  final day = DateTime(2026, 9, 14);

  HealthDataPoint point(
    HealthDataType type,
    double value, {
    HealthDataUnit? unit,
    HealthPlatformType platform = HealthPlatformType.appleHealth,
    DateTime? from,
    DateTime? to,
    String? uuid,
    HealthValue? healthValue,
  }) {
    final start = from ?? day.add(const Duration(hours: 6));
    return HealthDataPoint(
      uuid: uuid ?? '$type-$start-$value-$platform',
      value: healthValue ?? NumericHealthValue(numericValue: value),
      type: type,
      unit: unit ?? DailyHealthMetricNormalizer.units[type]!,
      dateFrom: start,
      dateTo: to ?? start,
      sourcePlatform: platform,
      sourceDeviceId: 'watch',
      sourceId: 'provider',
      sourceName: 'Watch',
    );
  }

  test('Apple oxygen is converted before averaging, storage and charting', () {
    final result = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.BLOOD_OXYGEN, 0.965),
      point(HealthDataType.BLOOD_OXYGEN, 0.98),
    ]);
    final log = result['spo2']!.single;
    expect(log.value, closeTo(97.25, 0.000001));
    // Round-trip the persisted representation: neither storage nor display
    // should convert a second time or round away the imported precision.
    final restored = BodyMetricLog.fromJson(log.toJson());
    expect(restored.value, log.value);
    final chart = buildDailySeries(
      logs: [restored],
      type: 'spo2',
      endDate: day,
      days: 1,
    );
    expect(chart.single.value, log.value);
    expect(log.value.toStringAsFixed(0), '97');
  });

  test('Apple 1 means 100 percent and Android values retain their scale', () {
    expect(
        DailyHealthMetricNormalizer.value(
            point(HealthDataType.BLOOD_OXYGEN, 1)),
        100);
    for (final value in [0.0, 0.97, 1.0, 97.0, 100.0]) {
      expect(
          DailyHealthMetricNormalizer.value(point(
            HealthDataType.BLOOD_OXYGEN,
            value,
            platform: HealthPlatformType.googleHealthConnect,
          )),
          value);
    }
  });

  test('mixed Apple and Android samples share a percentage scale', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.BLOOD_OXYGEN, 0.96),
      point(HealthDataType.BLOOD_OXYGEN, 98,
          platform: HealthPlatformType.googleHealthConnect),
    ]);
    expect(logs['spo2']!.single.value, 97);
  });

  test('invalid oxygen values and units do not poison a daily average', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      for (final value in [-1.0, 1.01, double.nan, double.infinity])
        point(HealthDataType.BLOOD_OXYGEN, value),
      point(HealthDataType.BLOOD_OXYGEN, 101,
          platform: HealthPlatformType.googleHealthConnect),
      point(HealthDataType.BLOOD_OXYGEN, 0.5, unit: HealthDataUnit.COUNT),
      point(HealthDataType.BLOOD_OXYGEN, 0.98),
    ]);
    expect(logs['spo2']!.single.value, 98);
    expect(
        DailyHealthMetricNormalizer.aggregate([
          point(HealthDataType.BLOOD_OXYGEN, double.nan),
        ])['spo2'],
        isEmpty);
  });

  test('RHR and respiration stay in bpm and breaths per minute', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.RESTING_HEART_RATE, 52.5),
      point(HealthDataType.RESPIRATORY_RATE, 14.25),
      point(HealthDataType.RESTING_HEART_RATE, 0),
      point(HealthDataType.RESPIRATORY_RATE, double.infinity),
    ]);
    expect(logs['resting_hr']!.single.value, 52.5);
    expect(logs['resp']!.single.value, 14.25);
  });

  test('HRV keeps SDNN and RMSSD separate, in milliseconds', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 0.0525,
          unit: HealthDataUnit.SECOND),
      point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 45.75,
          platform: HealthPlatformType.googleHealthConnect),
    ]);
    expect(logs['hrv_sdnn']!.single.value, 52.5);
    expect(logs['hrv_rmssd']!.single.value, 45.75);
  });

  test('HRV includes local midnight through 07:59, excluding 08:00', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 40, from: day),
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 60,
          from: day.add(const Duration(hours: 7, minutes: 59, seconds: 59))),
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 200,
          from: day.add(const Duration(hours: 8))),
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 300,
          from: day.add(const Duration(hours: 8, minutes: 59))),
    ]);
    expect(logs['hrv_sdnn']!.single.value, 50);
  });

  test('dates and HRV windows use local time even with UTC input', () {
    final local = DateTime(2026, 9, 14, 0, 15);
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 55,
          from: local.toUtc()),
    ]);
    expect(logs['hrv_sdnn']!.single.date, '2026-09-14');
  });

  test('weight converts explicit units to kilograms', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.WEIGHT, 70),
      point(HealthDataType.WEIGHT, 70000, unit: HealthDataUnit.GRAM),
      point(HealthDataType.WEIGHT, 70 / 0.45359237, unit: HealthDataUnit.POUND),
    ]);
    expect(logs['weight']!.single.value, closeTo(70, 0.000001));
  });

  test('wrist temperature belongs to the wake date and remains absolute', () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.SLEEP_WRIST_TEMPERATURE, 95,
          unit: HealthDataUnit.DEGREE_FAHRENHEIT,
          from: DateTime(2026, 9, 13, 23),
          to: DateTime(2026, 9, 14, 7)),
    ]);
    expect(logs['wrist_temp_c']!.single.date, '2026-09-14');
    expect(logs['wrist_temp_c']!.single.value, 35);
    expect(logs['skin_temp_delta_c'], isEmpty);
  });

  test('Android temperature deltas preserve negative and zero readings', () {
    for (final delta in [-0.5, 0.0, 0.5]) {
      final normalized = DailyHealthMetricNormalizer.value(point(
        HealthDataType.SKIN_TEMPERATURE,
        0,
        platform: HealthPlatformType.googleHealthConnect,
        unit: HealthDataUnit.DEGREE_FAHRENHEIT,
        healthValue: SkinTemperatureHealthValue(
          temperatureDelta: delta * 1.8,
          baseline: 95,
        ),
      ));
      expect(normalized, closeTo(delta, 0.000001));
    }
  });

  test('duplicate native samples are ignored without merging distinct ones',
      () {
    final first = point(HealthDataType.BLOOD_OXYGEN, 0.96, uuid: 'a');
    final logs = DailyHealthMetricNormalizer.aggregate([
      first,
      first,
      point(HealthDataType.BLOOD_OXYGEN, 1, uuid: 'b'),
    ]);
    expect(logs['spo2']!.single.value, 98);
  });

  test('temperature observations sharing a native record retain all timestamps',
      () {
    final logs = DailyHealthMetricNormalizer.aggregate([
      point(HealthDataType.SKIN_TEMPERATURE, -0.5, uuid: 'record'),
      point(HealthDataType.SKIN_TEMPERATURE, 0.5,
          uuid: 'record', from: day.add(const Duration(hours: 7))),
    ]);
    expect(logs['skin_temp_delta_c']!.single.value, 0);
  });

  test('repair re-reads the oldest suspect day without guessing stored values',
      () {
    BodyMetricLog log(String date, double value, {String type = 'spo2'}) =>
        BodyMetricLog(id: '$date-$type', date: date, type: type, value: value);
    final stored = [
      log('2026-09-01', 0.97),
      log('2025-03-02', 1),
      log('2024-01-01', 98),
      log('2023-01-01', 0.3, type: 'skin_temp_delta_c'),
      log('invalid', 0.98),
      log('2022-01-01', double.nan),
    ];
    expect(DailyHealthMetricNormalizer.oxygenHistoryStart(stored),
        DateTime(2025, 3, 2));
    expect(stored.first.value, 0.97);
    expect(
        DailyHealthMetricNormalizer.oxygenHistoryStart([
          log('2025-03-02', 100),
          log('2026-09-01', 97),
        ]),
        isNull);
  });
}
