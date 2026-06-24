import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:flutter_mobile/services/health_sync_service.dart';

void main() {
  group('HealthSyncService sleep aggregation', () {
    test('assigns pre-midnight stages to the wake-up date', () {
      final service = HealthSyncService();
      final points = [
        _sleepPoint(
          type: HealthDataType.SLEEP_DEEP,
          from: DateTime(2026, 6, 20, 23, 0),
          to: DateTime(2026, 6, 20, 23, 45),
        ),
        _sleepPoint(
          type: HealthDataType.SLEEP_LIGHT,
          from: DateTime(2026, 6, 20, 23, 45),
          to: DateTime(2026, 6, 21, 1, 0),
        ),
        _sleepPoint(
          type: HealthDataType.SLEEP_DEEP,
          from: DateTime(2026, 6, 21, 1, 0),
          to: DateTime(2026, 6, 21, 1, 30),
        ),
      ];

      final result = service.aggregateSleepForTesting(
        points,
        DateTime(2026, 6, 21),
      );

      expect(result['deepSleepMinutes'], 75);
      expect(result['lightSleepMinutes'], 75);
      expect(result['totalSleepMinutes'], 150);
    });

    test('keeps fractional minutes across individual stages', () {
      final service = HealthSyncService();
      final points = [
        _sleepPoint(
          type: HealthDataType.SLEEP_DEEP,
          from: DateTime(2026, 6, 20, 23, 0),
          to: DateTime(2026, 6, 20, 23, 0, 30),
        ),
        _sleepPoint(
          type: HealthDataType.SLEEP_DEEP,
          from: DateTime(2026, 6, 20, 23, 0, 30),
          to: DateTime(2026, 6, 20, 23, 1),
        ),
      ];

      final result = service.aggregateSleepForTesting(
        points,
        DateTime(2026, 6, 21),
      );

      expect(result['deepSleepMinutes'], 1);
      expect(result['totalSleepMinutes'], 1);
    });
  });
}

HealthDataPoint _sleepPoint({
  required HealthDataType type,
  required DateTime from,
  required DateTime to,
}) {
  return HealthDataPoint(
    uuid: '${type.name}-${from.toIso8601String()}',
    value: NumericHealthValue(numericValue: 0),
    type: type,
    unit: HealthDataUnit.MINUTE,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'test-device',
    sourceId: 'test-source',
    sourceName: 'test-source',
  );
}
