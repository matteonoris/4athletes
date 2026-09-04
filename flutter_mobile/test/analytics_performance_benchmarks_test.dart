import 'package:flutter_mobile/utils/analytics_performance_benchmarks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assegna le fasce anagrafiche e SENIOR solo oltre i 21 anni', () {
    expect(athleteBenchmarkAgeGroupForAge(13), AthleteBenchmarkAgeGroup.u14);
    expect(athleteBenchmarkAgeGroupForAge(14), AthleteBenchmarkAgeGroup.u16);
    expect(athleteBenchmarkAgeGroupForAge(15), AthleteBenchmarkAgeGroup.u16);
    expect(athleteBenchmarkAgeGroupForAge(16), AthleteBenchmarkAgeGroup.u18);
    expect(athleteBenchmarkAgeGroupForAge(17), AthleteBenchmarkAgeGroup.u18);
    expect(athleteBenchmarkAgeGroupForAge(18), AthleteBenchmarkAgeGroup.u21);
    expect(athleteBenchmarkAgeGroupForAge(21), AthleteBenchmarkAgeGroup.u21);
    expect(
      athleteBenchmarkAgeGroupForAge(22),
      AthleteBenchmarkAgeGroup.senior,
    );
  });

  test('calcola l eta alla data di riferimento e normalizza il sesso', () {
    final still21 = AnalyticsBenchmarkProfile.fromDemographics(
      birthDate: '2004-09-05',
      gender: 'Maschile',
      onDate: DateTime(2026, 9, 4),
    );
    final just22 = AnalyticsBenchmarkProfile.fromDemographics(
      birthDate: '2004-09-04',
      gender: 'F',
      onDate: DateTime(2026, 9, 4),
    );

    expect(still21?.ageGroup, AthleteBenchmarkAgeGroup.u21);
    expect(still21?.sex, AthleteBenchmarkSex.male);
    expect(just22?.ageGroup, AthleteBenchmarkAgeGroup.senior);
    expect(just22?.sex, AthleteBenchmarkSex.female);
    expect(
      AnalyticsBenchmarkProfile.fromDemographics(
        birthDate: 'data-non-valida',
        gender: 'M',
      ),
      isNull,
    );
  });

  test('rispetta le soglie Discreto e Buono di ogni tabella demografica', () {
    const expected = <(AthleteBenchmarkAgeGroup, AthleteBenchmarkSex),
        Map<String, (double, double, bool)>>{
      (AthleteBenchmarkAgeGroup.u14, AthleteBenchmarkSex.male): {
        'squat_jump': (26, 30, true),
        'cm_jump': (28, 32, true),
        'single_leg_left': (13, 16, true),
        'single_leg_right': (13, 16, true),
        'drop_jump': (24, 28, true),
        'drop_jump_rsi': (0.96, 1.21, true),
        '45s_jump': (20, 24, true),
        'sprint_20m': (3.30, 3.15, false),
        'sprint_60m': (8.80, 8.40, false),
        'leger_vo2max': (49, 53, true),
        'pullups_max': (4, 7, true),
      },
      (AthleteBenchmarkAgeGroup.u14, AthleteBenchmarkSex.female): {
        'squat_jump': (22, 25, true),
        'cm_jump': (25, 29, true),
        'single_leg_left': (10, 12, true),
        'single_leg_right': (10, 12, true),
        'drop_jump': (19, 22, true),
        'drop_jump_rsi': (0.86, 1.06, true),
        '45s_jump': (17, 20, true),
        'sprint_20m': (3.45, 3.30, false),
        'sprint_60m': (9.20, 8.80, false),
        'leger_vo2max': (44, 48, true),
        'pullups_max': (1, 3, true),
      },
      (AthleteBenchmarkAgeGroup.u16, AthleteBenchmarkSex.male): {
        'squat_jump': (32, 36, true),
        'cm_jump': (35, 40, true),
        'single_leg_left': (16, 19, true),
        'single_leg_right': (16, 19, true),
        'drop_jump': (26, 30, true),
        'drop_jump_rsi': (1.11, 1.36, true),
        '45s_jump': (24, 28, true),
        'sprint_20m': (3.10, 2.95, false),
        'sprint_60m': (8.20, 7.90, false),
        'leger_vo2max': (53, 57, true),
        'pullups_max': (7, 11, true),
      },
      (AthleteBenchmarkAgeGroup.u16, AthleteBenchmarkSex.female): {
        'squat_jump': (25, 28, true),
        'cm_jump': (28, 32, true),
        'single_leg_left': (12, 14, true),
        'single_leg_right': (12, 14, true),
        'drop_jump': (23, 27, true),
        'drop_jump_rsi': (1.01, 1.26, true),
        '45s_jump': (20, 23, true),
        'sprint_20m': (3.30, 3.15, false),
        'sprint_60m': (8.75, 8.40, false),
        'leger_vo2max': (47, 51, true),
        'pullups_max': (2, 4, true),
      },
      (AthleteBenchmarkAgeGroup.u18, AthleteBenchmarkSex.male): {
        'squat_jump': (37, 41, true),
        'cm_jump': (41, 46, true),
        'single_leg_left': (19, 22, true),
        'single_leg_right': (19, 22, true),
        'drop_jump': (32, 37, true),
        'drop_jump_rsi': (1.36, 1.66, true),
        '45s_jump': (28, 32, true),
        'sprint_20m': (3.00, 2.85, false),
        'sprint_60m': (7.80, 7.50, false),
        'leger_vo2max': (56, 60, true),
        'pullups_max': (10, 14, true),
      },
      (AthleteBenchmarkAgeGroup.u18, AthleteBenchmarkSex.female): {
        'squat_jump': (28, 31, true),
        'cm_jump': (32, 36, true),
        'single_leg_left': (14, 16, true),
        'single_leg_right': (14, 16, true),
        'drop_jump': (26, 30, true),
        'drop_jump_rsi': (1.21, 1.46, true),
        '45s_jump': (23, 26, true),
        'sprint_20m': (3.20, 3.05, false),
        'sprint_60m': (8.45, 8.10, false),
        'leger_vo2max': (49, 53, true),
        'pullups_max': (4, 6, true),
      },
      (AthleteBenchmarkAgeGroup.u21, AthleteBenchmarkSex.male): {
        'squat_jump': (41, 45, true),
        'cm_jump': (46, 51, true),
        'single_leg_left': (21, 25, true),
        'single_leg_right': (21, 25, true),
        'drop_jump': (36, 41, true),
        'drop_jump_rsi': (1.61, 1.96, true),
        '45s_jump': (31, 35, true),
        'sprint_20m': (2.95, 2.80, false),
        'sprint_60m': (7.65, 7.35, false),
        'leger_vo2max': (58, 62, true),
        'pullups_max': (12, 16, true),
      },
      (AthleteBenchmarkAgeGroup.u21, AthleteBenchmarkSex.female): {
        'squat_jump': (30, 33, true),
        'cm_jump': (35, 39, true),
        'single_leg_left': (16, 18, true),
        'single_leg_right': (16, 18, true),
        'drop_jump': (29, 33, true),
        'drop_jump_rsi': (1.36, 1.61, true),
        '45s_jump': (25, 28, true),
        'sprint_20m': (3.15, 3.00, false),
        'sprint_60m': (8.35, 8.00, false),
        'leger_vo2max': (50, 54, true),
        'pullups_max': (5, 8, true),
      },
      (AthleteBenchmarkAgeGroup.senior, AthleteBenchmarkSex.male): {
        'squat_jump': (44, 49, true),
        'cm_jump': (50, 56, true),
        'single_leg_left': (23, 27, true),
        'single_leg_right': (23, 27, true),
        'drop_jump': (39, 45, true),
        'drop_jump_rsi': (1.81, 2.16, true),
        '45s_jump': (36, 40, true),
        'sprint_20m': (2.90, 2.75, false),
        'sprint_60m': (7.50, 7.20, false),
        'leger_vo2max': (60, 64, true),
        'pullups_max': (14, 18, true),
      },
      (AthleteBenchmarkAgeGroup.senior, AthleteBenchmarkSex.female): {
        'squat_jump': (34, 38, true),
        'cm_jump': (38, 43, true),
        'single_leg_left': (18, 21, true),
        'single_leg_right': (18, 21, true),
        'drop_jump': (32, 37, true),
        'drop_jump_rsi': (1.51, 1.81, true),
        '45s_jump': (28, 31, true),
        'sprint_20m': (3.10, 2.95, false),
        'sprint_60m': (8.20, 7.85, false),
        'leger_vo2max': (52, 56, true),
        'pullups_max': (7, 10, true),
      },
    };

    for (final demographic in expected.entries) {
      final profile = AnalyticsBenchmarkProfile(
        ageGroup: demographic.key.$1,
        sex: demographic.key.$2,
      );
      for (final metric in demographic.value.entries) {
        final discrete = metric.value.$1;
        final positive = metric.value.$2;
        final higherIsBetter = metric.value.$3;
        final negativeValue =
            higherIsBetter ? discrete - 0.01 : discrete + 0.01;
        final betweenThresholds = (discrete + positive) / 2;

        expect(
          profile.bandFor(metric.key, negativeValue),
          AnalyticsPerformanceBand.negative,
          reason: '${demographic.key} ${metric.key} sotto il Discreto',
        );
        expect(
          profile.bandFor(metric.key, discrete),
          AnalyticsPerformanceBand.discrete,
          reason: '${demographic.key} ${metric.key} al limite Discreto',
        );
        expect(
          profile.bandFor(metric.key, betweenThresholds),
          AnalyticsPerformanceBand.discrete,
          reason: '${demographic.key} ${metric.key} tra Discreto e Buono',
        );
        expect(
          profile.bandFor(metric.key, positive),
          AnalyticsPerformanceBand.positive,
          reason: '${demographic.key} ${metric.key} al limite Buono',
        );
      }
    }
  });

  test('equilibrio usa soglie comuni e i dati non valutabili restano neutri',
      () {
    expect(
      analyticsPerformanceBandFor(
        profile: null,
        exerciseId: 'balance_bipedal',
        value: 3.21,
      ),
      AnalyticsPerformanceBand.negative,
    );
    expect(
      analyticsPerformanceBandFor(
        profile: null,
        exerciseId: 'balance_single_l',
        value: 3.2,
      ),
      AnalyticsPerformanceBand.discrete,
    );
    expect(
      analyticsPerformanceBandFor(
        profile: null,
        exerciseId: 'balance_single_r',
        value: 2.0,
      ),
      AnalyticsPerformanceBand.positive,
    );
    expect(
      analyticsPerformanceBandFor(
        profile: null,
        exerciseId: 'squat_jump',
        value: 50,
      ),
      AnalyticsPerformanceBand.neutral,
    );
    expect(
      analyticsPerformanceBandFor(
        profile: const AnalyticsBenchmarkProfile(
          ageGroup: AthleteBenchmarkAgeGroup.senior,
          sex: AthleteBenchmarkSex.male,
        ),
        exerciseId: 'leger_vam',
        value: 18,
      ),
      AnalyticsPerformanceBand.neutral,
    );
  });
}
