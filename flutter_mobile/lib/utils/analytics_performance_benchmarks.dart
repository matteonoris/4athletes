enum AnalyticsPerformanceBand { neutral, negative, discrete, positive }

enum AthleteBenchmarkAgeGroup { u14, u16, u18, u21, senior }

enum AthleteBenchmarkSex { male, female }

/// Athlete context used to select the correct row in the supplied benchmark
/// tables. U21 includes athletes through age 21; SENIOR starts above age 21.
class AnalyticsBenchmarkProfile {
  final AthleteBenchmarkAgeGroup ageGroup;
  final AthleteBenchmarkSex sex;

  const AnalyticsBenchmarkProfile({
    required this.ageGroup,
    required this.sex,
  });

  static AnalyticsBenchmarkProfile? fromDemographics({
    required String? birthDate,
    required String? gender,
    DateTime? onDate,
  }) {
    final birth = DateTime.tryParse(birthDate ?? '');
    final sex = athleteBenchmarkSexFromValue(gender);
    if (birth == null || sex == null) return null;

    final reference = onDate ?? DateTime.now();
    final birthday = DateTime(birth.year, birth.month, birth.day);
    final referenceDay =
        DateTime(reference.year, reference.month, reference.day);
    if (birthday.isAfter(referenceDay)) return null;

    var age = referenceDay.year - birthday.year;
    if (referenceDay.month < birthday.month ||
        (referenceDay.month == birthday.month &&
            referenceDay.day < birthday.day)) {
      age--;
    }

    return AnalyticsBenchmarkProfile(
      ageGroup: athleteBenchmarkAgeGroupForAge(age),
      sex: sex,
    );
  }

  AnalyticsPerformanceBand bandFor(String exerciseId, double value) {
    return analyticsPerformanceBandFor(
      profile: this,
      exerciseId: exerciseId,
      value: value,
    );
  }
}

AnalyticsPerformanceBand analyticsPerformanceBandFor({
  required AnalyticsBenchmarkProfile? profile,
  required String exerciseId,
  required double value,
}) {
  if (!value.isFinite || value <= 0) {
    return AnalyticsPerformanceBand.neutral;
  }

  final threshold = _sharedBenchmarks[exerciseId] ??
      (profile == null
          ? null
          : _benchmarksByDemographic[(profile.ageGroup, profile.sex)]
              ?[exerciseId]);
  return threshold?.classify(value) ?? AnalyticsPerformanceBand.neutral;
}

AthleteBenchmarkAgeGroup athleteBenchmarkAgeGroupForAge(int age) {
  if (age <= 13) return AthleteBenchmarkAgeGroup.u14;
  if (age <= 15) return AthleteBenchmarkAgeGroup.u16;
  if (age <= 17) return AthleteBenchmarkAgeGroup.u18;
  if (age <= 21) return AthleteBenchmarkAgeGroup.u21;
  return AthleteBenchmarkAgeGroup.senior;
}

AthleteBenchmarkSex? athleteBenchmarkSexFromValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'm':
    case 'male':
    case 'maschio':
    case 'maschile':
      return AthleteBenchmarkSex.male;
    case 'f':
    case 'female':
    case 'femmina':
    case 'femminile':
      return AthleteBenchmarkSex.female;
    default:
      return null;
  }
}

class _PerformanceThreshold {
  final double discrete;
  final double positive;
  final bool higherIsBetter;

  const _PerformanceThreshold(
    this.discrete,
    this.positive, {
    this.higherIsBetter = true,
  });

  AnalyticsPerformanceBand classify(double value) {
    if (higherIsBetter) {
      if (value >= positive) return AnalyticsPerformanceBand.positive;
      if (value >= discrete) return AnalyticsPerformanceBand.discrete;
    } else {
      if (value <= positive) return AnalyticsPerformanceBand.positive;
      if (value <= discrete) return AnalyticsPerformanceBand.discrete;
    }
    return AnalyticsPerformanceBand.negative;
  }
}

// Only columns represented by cards in Analytics are included. The first two
// source levels (Insufficiente and Sufficiente) map to red, Discreto to yellow,
// and Buono/Ottimo to green.
const _benchmarksByDemographic = <(
  AthleteBenchmarkAgeGroup,
  AthleteBenchmarkSex
),
    Map<String, _PerformanceThreshold>>{
  (AthleteBenchmarkAgeGroup.u14, AthleteBenchmarkSex.male): {
    'squat_jump': _PerformanceThreshold(26, 30),
    'cm_jump': _PerformanceThreshold(28, 32),
    'single_leg_left': _PerformanceThreshold(13, 16),
    'single_leg_right': _PerformanceThreshold(13, 16),
    'drop_jump': _PerformanceThreshold(24, 28),
    'drop_jump_rsi': _PerformanceThreshold(0.96, 1.21),
    '45s_jump': _PerformanceThreshold(20, 24),
    'sprint_20m': _PerformanceThreshold(3.30, 3.15, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.80, 8.40, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(49, 53),
    'pullups_max': _PerformanceThreshold(4, 7),
  },
  (AthleteBenchmarkAgeGroup.u14, AthleteBenchmarkSex.female): {
    'squat_jump': _PerformanceThreshold(22, 25),
    'cm_jump': _PerformanceThreshold(25, 29),
    'single_leg_left': _PerformanceThreshold(10, 12),
    'single_leg_right': _PerformanceThreshold(10, 12),
    'drop_jump': _PerformanceThreshold(19, 22),
    'drop_jump_rsi': _PerformanceThreshold(0.86, 1.06),
    '45s_jump': _PerformanceThreshold(17, 20),
    'sprint_20m': _PerformanceThreshold(3.45, 3.30, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(9.20, 8.80, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(44, 48),
    'pullups_max': _PerformanceThreshold(1, 3),
  },
  (AthleteBenchmarkAgeGroup.u16, AthleteBenchmarkSex.male): {
    'squat_jump': _PerformanceThreshold(32, 36),
    'cm_jump': _PerformanceThreshold(35, 40),
    'single_leg_left': _PerformanceThreshold(16, 19),
    'single_leg_right': _PerformanceThreshold(16, 19),
    'drop_jump': _PerformanceThreshold(26, 30),
    'drop_jump_rsi': _PerformanceThreshold(1.11, 1.36),
    '45s_jump': _PerformanceThreshold(24, 28),
    'sprint_20m': _PerformanceThreshold(3.10, 2.95, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.20, 7.90, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(53, 57),
    'pullups_max': _PerformanceThreshold(7, 11),
  },
  (AthleteBenchmarkAgeGroup.u16, AthleteBenchmarkSex.female): {
    'squat_jump': _PerformanceThreshold(25, 28),
    'cm_jump': _PerformanceThreshold(28, 32),
    'single_leg_left': _PerformanceThreshold(12, 14),
    'single_leg_right': _PerformanceThreshold(12, 14),
    'drop_jump': _PerformanceThreshold(23, 27),
    'drop_jump_rsi': _PerformanceThreshold(1.01, 1.26),
    '45s_jump': _PerformanceThreshold(20, 23),
    'sprint_20m': _PerformanceThreshold(3.30, 3.15, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.75, 8.40, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(47, 51),
    'pullups_max': _PerformanceThreshold(2, 4),
  },
  (AthleteBenchmarkAgeGroup.u18, AthleteBenchmarkSex.male): {
    'squat_jump': _PerformanceThreshold(37, 41),
    'cm_jump': _PerformanceThreshold(41, 46),
    'single_leg_left': _PerformanceThreshold(19, 22),
    'single_leg_right': _PerformanceThreshold(19, 22),
    'drop_jump': _PerformanceThreshold(32, 37),
    'drop_jump_rsi': _PerformanceThreshold(1.36, 1.66),
    '45s_jump': _PerformanceThreshold(28, 32),
    'sprint_20m': _PerformanceThreshold(3.00, 2.85, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(7.80, 7.50, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(56, 60),
    'pullups_max': _PerformanceThreshold(10, 14),
  },
  (AthleteBenchmarkAgeGroup.u18, AthleteBenchmarkSex.female): {
    'squat_jump': _PerformanceThreshold(28, 31),
    'cm_jump': _PerformanceThreshold(32, 36),
    'single_leg_left': _PerformanceThreshold(14, 16),
    'single_leg_right': _PerformanceThreshold(14, 16),
    'drop_jump': _PerformanceThreshold(26, 30),
    'drop_jump_rsi': _PerformanceThreshold(1.21, 1.46),
    '45s_jump': _PerformanceThreshold(23, 26),
    'sprint_20m': _PerformanceThreshold(3.20, 3.05, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.45, 8.10, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(49, 53),
    'pullups_max': _PerformanceThreshold(4, 6),
  },
  (AthleteBenchmarkAgeGroup.u21, AthleteBenchmarkSex.male): {
    'squat_jump': _PerformanceThreshold(41, 45),
    'cm_jump': _PerformanceThreshold(46, 51),
    'single_leg_left': _PerformanceThreshold(21, 25),
    'single_leg_right': _PerformanceThreshold(21, 25),
    'drop_jump': _PerformanceThreshold(36, 41),
    'drop_jump_rsi': _PerformanceThreshold(1.61, 1.96),
    '45s_jump': _PerformanceThreshold(31, 35),
    'sprint_20m': _PerformanceThreshold(2.95, 2.80, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(7.65, 7.35, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(58, 62),
    'pullups_max': _PerformanceThreshold(12, 16),
  },
  (AthleteBenchmarkAgeGroup.u21, AthleteBenchmarkSex.female): {
    'squat_jump': _PerformanceThreshold(30, 33),
    'cm_jump': _PerformanceThreshold(35, 39),
    'single_leg_left': _PerformanceThreshold(16, 18),
    'single_leg_right': _PerformanceThreshold(16, 18),
    'drop_jump': _PerformanceThreshold(29, 33),
    'drop_jump_rsi': _PerformanceThreshold(1.36, 1.61),
    '45s_jump': _PerformanceThreshold(25, 28),
    'sprint_20m': _PerformanceThreshold(3.15, 3.00, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.35, 8.00, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(50, 54),
    'pullups_max': _PerformanceThreshold(5, 8),
  },
  (AthleteBenchmarkAgeGroup.senior, AthleteBenchmarkSex.male): {
    'squat_jump': _PerformanceThreshold(44, 49),
    'cm_jump': _PerformanceThreshold(50, 56),
    'single_leg_left': _PerformanceThreshold(23, 27),
    'single_leg_right': _PerformanceThreshold(23, 27),
    'drop_jump': _PerformanceThreshold(39, 45),
    'drop_jump_rsi': _PerformanceThreshold(1.81, 2.16),
    '45s_jump': _PerformanceThreshold(36, 40),
    'sprint_20m': _PerformanceThreshold(2.90, 2.75, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(7.50, 7.20, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(60, 64),
    'pullups_max': _PerformanceThreshold(14, 18),
  },
  (AthleteBenchmarkAgeGroup.senior, AthleteBenchmarkSex.female): {
    'squat_jump': _PerformanceThreshold(34, 38),
    'cm_jump': _PerformanceThreshold(38, 43),
    'single_leg_left': _PerformanceThreshold(18, 21),
    'single_leg_right': _PerformanceThreshold(18, 21),
    'drop_jump': _PerformanceThreshold(32, 37),
    'drop_jump_rsi': _PerformanceThreshold(1.51, 1.81),
    '45s_jump': _PerformanceThreshold(28, 31),
    'sprint_20m': _PerformanceThreshold(3.10, 2.95, higherIsBetter: false),
    'sprint_60m': _PerformanceThreshold(8.20, 7.85, higherIsBetter: false),
    'leger_vo2max': _PerformanceThreshold(52, 56),
    'pullups_max': _PerformanceThreshold(7, 10),
  },
};

const _sharedBenchmarks = <String, _PerformanceThreshold>{
  'balance_bipedal': _PerformanceThreshold(3.2, 2.0, higherIsBetter: false),
  'balance_single_l': _PerformanceThreshold(3.2, 2.0, higherIsBetter: false),
  'balance_single_r': _PerformanceThreshold(3.2, 2.0, higherIsBetter: false),
};
