import 'dart:math' as math;

import 'package:flutter_mobile/utils/hrv_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HrvEngine signal quality', () {
    test('keeps elite bradycardia intervals up to 2000 ms', () {
      final raw = List<double>.generate(
        40,
        (index) => index.isEven ? 1600 : 1610,
      );
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: raw,
        deviceSource: 'test-device',
        historicalData: const [],
      );

      expect(result['quality_passed'], isTrue);
      expect(result['valid_interval_count'], 40);
      expect(result['artifact_count'], 0);
      expect(result['rmssd'], closeTo(10, 0.000001));
      expect(
        HrvEngine.cleanRRIntervals([1990, 2000, 2100]),
        [1990, 2000],
      );
    });

    test('rejects a recording with too few intervals', () {
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: List<double>.filled(10, 1000),
        deviceSource: 'test-device',
        historicalData: const [],
      );

      expect(result['rmssd'], 0);
      expect(result['quality_passed'], isFalse);
      expect(
        result['quality_warnings'],
        contains('hrv_insufficient_raw_intervals'),
      );
    });

    test('rejects excessive artifact burden', () {
      final raw = List<double>.generate(
        40,
        (index) => index % 4 == 0 ? 100 : (index.isEven ? 1000 : 1010),
      );
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: raw,
        deviceSource: 'test-device',
        historicalData: const [],
      );

      expect(result['quality_passed'], isFalse);
      expect(result['artifact_fraction'], greaterThan(0.10));
      expect(
        result['quality_warnings'],
        contains('hrv_excessive_artifact_fraction'),
      );
    });

    test('RMSSD does not join intervals across a discarded artifact', () {
      final raw = List<double>.generate(40, (index) {
        if (index == 20) return 100;
        if (index < 20) return index.isEven ? 1000 : 1010;
        return index.isEven ? 1100 : 1110;
      });
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: raw,
        deviceSource: 'test-device',
        historicalData: const [],
      );

      expect(result['quality_passed'], isTrue);
      expect(result['artifact_count'], 1);
      expect(result['rmssd'], closeTo(10, 0.000001));
    });
  });

  group('HrvEngine longitudinal aggregation', () {
    test('uses a geometric rolling mean', () {
      final history = List.generate(7, (index) {
        return {
          'date': '2026-01-0${index + 1}',
          'rmssd': 25.0 + index * 5,
          'device_source': 'test-device',
        };
      });
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: List<double>.generate(
          40,
          (index) => index.isEven ? 1000 : 1010,
        ),
        deviceSource: 'test-device',
        historicalData: history,
      );
      final recent = [30.0, 35, 40, 45, 50, 55, result['rmssd'] as double];
      final expected = math.exp(
        recent.map(math.log).reduce((a, b) => a + b) / recent.length,
      );

      expect(result['rolling_method'], 'geometric_mean');
      expect(result['rolling_7d'], closeTo(expected, 0.000001));
    });

    test('re-sync replaces the current date instead of duplicating it', () {
      final history = List.generate(7, (index) {
        return {
          'date': '2026-01-0${index + 1}',
          'rmssd': 20.0 + index * 10,
          'device_source': 'test-device',
        };
      });
      final result = HrvEngine.processNightlyHrv(
        rawRRIntervals: List<double>.generate(
          40,
          (index) => index.isEven ? 1000 : 1010,
        ),
        deviceSource: 'test-device',
        historicalData: history,
        measurementDate: '2026-01-07',
      );
      final expectedValues = [
        20.0,
        30,
        40,
        50,
        60,
        70,
        result['rmssd'] as double,
      ];
      final expected = math.exp(
        expectedValues.map(math.log).reduce((a, b) => a + b) /
            expectedValues.length,
      );

      expect(result['measurement_date'], '2026-01-07');
      expect(result['rolling_7d'], closeTo(expected, 0.000001));
    });
  });
}
