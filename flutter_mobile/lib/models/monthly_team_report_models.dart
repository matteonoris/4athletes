import 'models.dart';

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
  final double totalSkiHours;
  final double totalAthleticHours;
  final double totalOutOfProgramHours;
  final int totalDirectionChanges;
  final double totalStrengthVolumeKg;
  final int totalStrengthSets;
  final double totalEnduranceMeters;
  final int testSessionCount;
  final int incompleteDataCount;

  const MonthlyTeamReportSummary({
    required this.totalAthletes,
    required this.athletesWithActivity,
    required this.athletesWithoutData,
    required this.averageSkiPresence,
    required this.averageAthleticPresence,
    required this.totalSkiHours,
    required this.totalAthleticHours,
    required this.totalOutOfProgramHours,
    required this.totalDirectionChanges,
    required this.totalStrengthVolumeKg,
    required this.totalStrengthSets,
    required this.totalEnduranceMeters,
    required this.testSessionCount,
    required this.incompleteDataCount,
  });
}

class MonthlyTeamSkiReport {
  final int totalDirectionChanges;
  final int clDirectionChanges;
  final int slDirectionChanges;
  final int gsDirectionChanges;
  final int addestramentoDirectionChanges;
  final Map<String, int> directionChangesByDiscipline;

  const MonthlyTeamSkiReport({
    required this.totalDirectionChanges,
    required this.clDirectionChanges,
    required this.slDirectionChanges,
    required this.gsDirectionChanges,
    required this.addestramentoDirectionChanges,
    required this.directionChangesByDiscipline,
  });
}

class MonthlyTeamAthleticReport {
  final double totalHours;
  final double totalStrengthVolumeKg;
  final int totalStrengthSets;
  final int totalDrills;
  final double totalEnduranceMeters;
  final Map<String, double> hoursByCategory;

  const MonthlyTeamAthleticReport({
    required this.totalHours,
    required this.totalStrengthVolumeKg,
    required this.totalStrengthSets,
    required this.totalDrills,
    required this.totalEnduranceMeters,
    required this.hoursByCategory,
  });
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
  });

  double get scheduledHours => scheduledSkiHours + scheduledAthleticHours;

  double get outOfProgramHours =>
      outOfProgramSkiHours + outOfProgramAthleticHours;

  double get totalSkiHours => scheduledSkiHours + outOfProgramSkiHours;

  double get totalAthleticHours =>
      scheduledAthleticHours + outOfProgramAthleticHours;

  double get totalHours => totalSkiHours + totalAthleticHours;
}

class MonthlyTeamReport {
  final Team team;
  final String month;
  final DateTime generatedAt;
  final MonthlyTeamReportSummary summary;
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
    required this.athletes,
    required this.ski,
    required this.athletic,
    required this.tests,
    required this.alerts,
    required this.automaticSummary,
  });
}
