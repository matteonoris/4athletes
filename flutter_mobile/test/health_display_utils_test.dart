import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/health_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in ['sleep_score', 'recovery_score']) {
    test('$type keeps zero, removes invalid revisions and deduplicates dates',
        () {
      final series = buildDailySeries(logs: [
        BodyMetricLog(id: 'old', date: '2026-06-01', type: type, value: 90),
        BodyMetricLog(id: 'new', date: '2026-06-01', type: type, value: 58),
        BodyMetricLog(id: 'zero', date: '2026-06-02', type: type, value: 0),
        BodyMetricLog(
            id: 'invalid', date: '2026-06-03', type: type, value: 101),
        BodyMetricLog(id: 'old4', date: '2026-06-04', type: type, value: 95),
        BodyMetricLog(
            id: 'invalid4', date: '2026-06-04', type: type, value: double.nan),
      ], type: type, endDate: DateTime(2026, 6, 5), days: 5);
      expect(series.map((point) => point.value).toList(),
          [58, 0, null, null, null]);
    });
  }
  test('readiness status follows the requested recovery scale', () {
    expect(readinessStatus(90), 'Molto alto');
    expect(readinessStatus(70), 'Buono');
    expect(readinessStatus(55), 'Moderato');
    expect(readinessStatus(40), 'Basso');
    expect(readinessStatus(39), 'Molto basso');
  });

  test('daily series keeps missing days as null chart points', () {
    final endDate = DateTime(2026, 6, 4);
    final series = buildDailySeries(
      logs: [
        BodyMetricLog(id: '1', date: '2026-06-02', type: 'hrv', value: 61),
        BodyMetricLog(id: '2', date: '2026-06-04', type: 'hrv', value: 64),
      ],
      type: 'hrv',
      endDate: endDate,
      days: 3,
    );

    expect(series.map((point) => point.value).toList(), [61, null, 64]);
  });

  test('rolling baseline uses visible 30 day history before today', () {
    final baseline = rollingBaseline(
      [
        BodyMetricLog(
            id: '1', date: '2026-06-01', type: 'resting_hr', value: 50),
        BodyMetricLog(
            id: '2', date: '2026-06-02', type: 'resting_hr', value: 52),
        BodyMetricLog(
            id: '3', date: '2026-06-04', type: 'resting_hr', value: 60),
      ],
      'resting_hr',
      DateTime(2026, 6, 4),
    );

    expect(baseline, 51);
  });

  test('height chart is shown only for athletes under 18', () {
    final minor = _profile('2010-01-01');
    final adult = _profile('1990-01-01');

    expect(shouldShowHeightChart(minor), isTrue);
    expect(shouldShowHeightChart(adult), isFalse);
  });
}

UserProfile _profile(String birthDate) {
  return UserProfile(
    firstName: 'Test',
    lastName: 'Athlete',
    email: 'test@example.com',
    birthDate: birthDate,
    role: 'athlete',
    weight: 70,
    height: 175,
    maxHr: 190,
    unitSystem: 'metric',
    language: 'it',
    avatarUrl: '',
    notificationsEnabled: false,
    connectedDevices: const [],
  );
}
