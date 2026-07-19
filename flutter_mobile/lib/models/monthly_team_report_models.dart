import 'models.dart';

class MonthlyTrainingMacro {
  static const ski = 'ski';
  static const preparation = 'preparation';
  static const otherSports = 'other_sports';
  static const recoveryOther = 'recovery_other';

  static const ordered = [ski, preparation, otherSports, recoveryOther];

  static String label(String id) {
    switch (id) {
      case ski:
        return 'Sci alpino';
      case preparation:
        return 'Preparazione atletica';
      case otherSports:
        return 'Altri sport';
      case recoveryOther:
      default:
        return 'Recupero / altro';
    }
  }
}

class TeamReportSession {
  final String athleteId;
  final TrainingSession session;

  const TeamReportSession({
    required this.athleteId,
    required this.session,
  });
}

class TeamReportMetricLog {
  final String athleteId;
  final String date;
  final String type;
  final double value;

  const TeamReportMetricLog({
    required this.athleteId,
    required this.date,
    required this.type,
    required this.value,
  });
}

class TeamReportPrLog {
  final String athleteId;
  final String date;
  final String exerciseId;
  final double weight;

  const TeamReportPrLog({
    required this.athleteId,
    required this.date,
    required this.exerciseId,
    required this.weight,
  });
}

class TeamReportAthleteProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String avatarUrl;
  final String skillLevel;

  const TeamReportAthleteProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl = '',
    this.skillLevel = '',
  });

  String get name {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'Atleta' : value;
  }

  String get initial => name.isEmpty ? 'A' : name[0].toUpperCase();
}

class MonthlyMetricDelta {
  final double current;
  final double? previous;

  const MonthlyMetricDelta({
    required this.current,
    required this.previous,
  });

  bool get hasPrevious => previous != null;

  double? get absoluteDelta => previous == null ? null : current - previous!;

  double? get percentDelta {
    final base = previous;
    if (base == null || base == 0) return null;
    return ((current - base) / base) * 100;
  }
}

class MonthlyTeamAlert {
  final String athleteId;
  final String athleteName;
  final String type;
  final String label;
  final String severity;

  const MonthlyTeamAlert({
    required this.athleteId,
    required this.athleteName,
    required this.type,
    required this.label,
    this.severity = 'warning',
  });
}

class MonthlyTeamReportSummary {
  final int totalAthletes;
  final int athletesWithActivity;
  final int athletesWithoutData;
  final double? averageSkiPresence;
  final double? averageAthleticPresence;
  final double averageAthleteHours;
  final int athleteHoursCoverage;
  final int testSessionCount;
  final int incompleteDataCount;

  const MonthlyTeamReportSummary({
    required this.totalAthletes,
    required this.athletesWithActivity,
    required this.athletesWithoutData,
    required this.averageSkiPresence,
    required this.averageAthleticPresence,
    required this.averageAthleteHours,
    required this.athleteHoursCoverage,
    required this.testSessionCount,
    required this.incompleteDataCount,
  });
}

class MonthlyTeamCoachWorkload {
  final int completedSkiSessions;
  final double completedSkiHours;
  final int completedPreparationSessions;
  final double completedPreparationHours;
  final int completedOtherSportSessions;
  final double completedOtherSportHours;
  final Map<String, double> preparationHoursByType;

  const MonthlyTeamCoachWorkload({
    required this.completedSkiSessions,
    required this.completedSkiHours,
    required this.completedPreparationSessions,
    required this.completedPreparationHours,
    required this.completedOtherSportSessions,
    required this.completedOtherSportHours,
    required this.preparationHoursByType,
  });

  int get completedSessionCount =>
      completedSkiSessions +
      completedPreparationSessions +
      completedOtherSportSessions;

  double get completedHours =>
      completedSkiHours + completedPreparationHours + completedOtherSportHours;
}

class MonthlyTeamSkiReport {
  final double averageDirectionChanges;
  final int validAthleteCount;
  final int skiActiveAthleteCount;
  final Map<String, double> averageDirectionChangesByDiscipline;

  const MonthlyTeamSkiReport({
    required this.averageDirectionChanges,
    required this.validAthleteCount,
    required this.skiActiveAthleteCount,
    required this.averageDirectionChangesByDiscipline,
  });
}

class MonthlyTeamAthleticReport {
  final double averageAthleteHours;
  final double averageStrengthVolumeKg;
  final double averageStrengthSets;
  final double averageDrills;
  final double averageEnduranceMeters;
  final int validAthleteCount;
  final int strengthVolumeCoverage;
  final int strengthSetsCoverage;
  final int drillCoverage;
  final int enduranceCoverage;
  final Map<String, double> averageHoursByCategory;

  const MonthlyTeamAthleticReport({
    required this.averageAthleteHours,
    required this.averageStrengthVolumeKg,
    required this.averageStrengthSets,
    required this.averageDrills,
    required this.averageEnduranceMeters,
    required this.validAthleteCount,
    required this.strengthVolumeCoverage,
    required this.strengthSetsCoverage,
    required this.drillCoverage,
    required this.enduranceCoverage,
    required this.averageHoursByCategory,
  });
}

class MonthlyAthleteTrendPoint {
  final String month;
  final int? throughDay;
  final int sessionCount;
  final double totalHours;
  final Map<String, double> hoursByMacro;
  final Map<String, double> preparationHoursByType;
  final int skiDirectionChanges;
  final double? skiPresence;
  final double? athleticPresence;
  final int incompleteDataCount;

  const MonthlyAthleteTrendPoint({
    required this.month,
    required this.throughDay,
    required this.sessionCount,
    required this.totalHours,
    required this.hoursByMacro,
    required this.preparationHoursByType,
    required this.skiDirectionChanges,
    required this.skiPresence,
    required this.athleticPresence,
    required this.incompleteDataCount,
  });

  double hoursFor(String macro) => hoursByMacro[macro] ?? 0;

  bool get hasActivity => sessionCount > 0 || totalHours > 0;
}

class MonthlyTeamTestsReport {
  final double? averageSquatJumpCm;
  final double? averageCmjCm;
  final double? averageDropJumpCm;
  final double? averageRsi;
  final double? averageSingleLegLeftCm;
  final double? averageSingleLegRightCm;
  final double? averageAsymmetryPercent;

  const MonthlyTeamTestsReport({
    required this.averageSquatJumpCm,
    required this.averageCmjCm,
    required this.averageDropJumpCm,
    required this.averageRsi,
    required this.averageSingleLegLeftCm,
    required this.averageSingleLegRightCm,
    required this.averageAsymmetryPercent,
  });
}

class MonthlyTeamAthleteReport {
  final String athleteId;
  final String athleteName;
  final String initial;
  final String avatarUrl;
  final String skillLevel;
  final bool hasAnyData;
  final double? skiPresence;
  final double? athleticPresence;
  final double scheduledSkiHours;
  final double outOfProgramSkiHours;
  final double scheduledAthleticHours;
  final double outOfProgramAthleticHours;
  final double externalCoachHours;
  final double individualHours;
  final double unclassifiedHours;
  final int totalDirectionChanges;
  final int clDirectionChanges;
  final int slDirectionChanges;
  final int gsDirectionChanges;
  final int sgDirectionChanges;
  final int dhDirectionChanges;
  final int sxDirectionChanges;
  final int addestramentoDirectionChanges;
  final double strengthVolumeKg;
  final int strengthSets;
  final int drillCount;
  final double enduranceMeters;
  final double? squatJumpCm;
  final double? cmjCm;
  final double? dropJumpCm;
  final double? rsi;
  final double? singleLegLeftCm;
  final double? singleLegRightCm;
  final double? asymmetryPercent;
  final int testSessionCount;
  final int incompleteDataCount;
  final List<MonthlyTeamAlert> alerts;
  final Map<String, MonthlyMetricDelta> deltas;
  final int sessionCount;
  final Map<String, double> hoursByMacro;
  final Map<String, double> preparationHoursByType;
  final List<MonthlyAthleteTrendPoint> trend;
  final String trendSummary;

  const MonthlyTeamAthleteReport({
    required this.athleteId,
    required this.athleteName,
    required this.initial,
    this.avatarUrl = '',
    this.skillLevel = '',
    required this.hasAnyData,
    required this.skiPresence,
    required this.athleticPresence,
    required this.scheduledSkiHours,
    required this.outOfProgramSkiHours,
    required this.scheduledAthleticHours,
    required this.outOfProgramAthleticHours,
    required this.externalCoachHours,
    required this.individualHours,
    required this.unclassifiedHours,
    required this.totalDirectionChanges,
    required this.clDirectionChanges,
    required this.slDirectionChanges,
    required this.gsDirectionChanges,
    required this.sgDirectionChanges,
    required this.dhDirectionChanges,
    required this.sxDirectionChanges,
    required this.addestramentoDirectionChanges,
    required this.strengthVolumeKg,
    required this.strengthSets,
    required this.drillCount,
    required this.enduranceMeters,
    required this.squatJumpCm,
    required this.cmjCm,
    required this.dropJumpCm,
    required this.rsi,
    required this.singleLegLeftCm,
    required this.singleLegRightCm,
    required this.asymmetryPercent,
    required this.testSessionCount,
    required this.incompleteDataCount,
    required this.alerts,
    required this.deltas,
    required this.sessionCount,
    required this.hoursByMacro,
    required this.preparationHoursByType,
    required this.trend,
    required this.trendSummary,
  });

  double get scheduledHours => scheduledSkiHours + scheduledAthleticHours;

  double get outOfProgramHours =>
      outOfProgramSkiHours + outOfProgramAthleticHours;

  double get totalSkiHours => scheduledSkiHours + outOfProgramSkiHours;

  double get totalAthleticHours =>
      scheduledAthleticHours + outOfProgramAthleticHours;

  double get otherSportHours =>
      hoursByMacro[MonthlyTrainingMacro.otherSports] ?? 0;

  double get recoveryOtherHours =>
      hoursByMacro[MonthlyTrainingMacro.recoveryOther] ?? 0;

  double get totalHours =>
      hoursByMacro.values.fold(0, (sum, value) => sum + value);

  MonthlyAthleteTrendPoint? get previousTrend =>
      trend.length < 2 ? null : trend[trend.length - 2];

  List<MonthlyAthleteTrendPoint> get previousSixTrend =>
      trend.length < 2 ? const [] : trend.take(trend.length - 1).toList();

  double? get previousSixAverageHours {
    final valid = previousSixTrend.where((point) => point.hasActivity).toList();
    if (valid.isEmpty) return null;
    return valid.fold<double>(0, (sum, point) => sum + point.totalHours) /
        valid.length;
  }
}

class MonthlyTeamReport {
  final Team team;
  final String month;
  final DateTime generatedAt;
  final MonthlyTeamReportSummary summary;
  final MonthlyTeamCoachWorkload coachWorkload;
  final List<MonthlyTeamAthleteReport> athletes;
  final MonthlyTeamSkiReport ski;
  final MonthlyTeamAthleticReport athletic;
  final MonthlyTeamTestsReport tests;
  final List<MonthlyTeamAlert> alerts;
  final String automaticSummary;

  const MonthlyTeamReport({
    required this.team,
    required this.month,
    required this.generatedAt,
    required this.summary,
    required this.coachWorkload,
    required this.athletes,
    required this.ski,
    required this.athletic,
    required this.tests,
    required this.alerts,
    required this.automaticSummary,
  });
}
