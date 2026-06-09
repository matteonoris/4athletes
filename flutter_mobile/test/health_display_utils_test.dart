import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/health_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
