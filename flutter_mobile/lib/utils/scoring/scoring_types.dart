enum Sex {
  male,
  female,
  other,
  unknown,
}

enum ScoreStatus {
  ok,
  partialData,
  calibrationPhase,
  insufficientData,
}

extension ScoreStatusCode on ScoreStatus {
  String get code {
    switch (this) {
      case ScoreStatus.ok:
        return 'OK';
      case ScoreStatus.partialData:
        return 'PARTIAL_DATA';
      case ScoreStatus.calibrationPhase:
        return 'CALIBRATION_PHASE';
      case ScoreStatus.insufficientData:
        return 'INSUFFICIENT_DATA';
    }
  }
}

class AthleteProfile {
  final String athleteId;
  final Sex sex;
  final bool isLutealPhase;
  final int? ageYears;
  final String timezone;

  const AthleteProfile({
    required this.athleteId,
    this.sex = Sex.unknown,
    this.isLutealPhase = false,
    this.ageYears,
    required this.timezone,
  });
}

enum StrainScoreStatus {
  ok,
  partialData,
  noTraining,
  insufficientData,
  calibrationPhase,
}

extension StrainScoreStatusCode on StrainScoreStatus {
  String get code {
    switch (this) {
      case StrainScoreStatus.ok:
        return 'OK';
      case StrainScoreStatus.partialData:
        return 'PARTIAL_DATA';
      case StrainScoreStatus.noTraining:
        return 'NO_TRAINING';
      case StrainScoreStatus.insufficientData:
        return 'INSUFFICIENT_DATA';
      case StrainScoreStatus.calibrationPhase:
        return 'CALIBRATION_PHASE';
    }
  }
}

enum StrainSportCategory {
  mobility,
  cycling,
  swimming,
  enduranceGeneric,
  running,
  football,
  strength,
  sprint,
  plyometrics,
  alpineSkiingTraining,
  alpineSkiingRace,
  teamSport,
  unknown,
}

extension StrainSportCategoryCode on StrainSportCategory {
  String get code {
    switch (this) {
      case StrainSportCategory.mobility:
        return 'mobility';
      case StrainSportCategory.cycling:
        return 'cycling';
      case StrainSportCategory.swimming:
        return 'swimming';
      case StrainSportCategory.enduranceGeneric:
        return 'endurance_generic';
      case StrainSportCategory.running:
        return 'running';
      case StrainSportCategory.football:
        return 'football';
      case StrainSportCategory.strength:
        return 'strength';
      case StrainSportCategory.sprint:
        return 'sprint';
      case StrainSportCategory.plyometrics:
        return 'plyometrics';
      case StrainSportCategory.alpineSkiingTraining:
        return 'alpine_skiing_training';
      case StrainSportCategory.alpineSkiingRace:
        return 'alpine_skiing_race';
      case StrainSportCategory.teamSport:
        return 'team_sport';
      case StrainSportCategory.unknown:
        return 'unknown';
    }
  }
}

class HeartRateSample {
  final String timestamp;
  final double bpm;

  const HeartRateSample({
    required this.timestamp,
    required this.bpm,
  });
}

class HeartRateZones {
  final double? belowZone1Minutes;
  final double? z1Minutes;
  final double? z2Minutes;
  final double? z3Minutes;
  final double? z4Minutes;
  final double? z5Minutes;

  const HeartRateZones({
    this.belowZone1Minutes,
    this.z1Minutes,
    this.z2Minutes,
    this.z3Minutes,
    this.z4Minutes,
    this.z5Minutes,
  });

  bool get hasAny =>
      belowZone1Minutes != null ||
      z1Minutes != null ||
      z2Minutes != null ||
      z3Minutes != null ||
      z4Minutes != null ||
      z5Minutes != null;
}

class WorkoutSessionInput {
  final String id;
  final String athleteId;
  final String date;
  final String? startTime;
  final String? endTime;
  final String sportType;
  final double durationMinutes;
  final double? rpe;
  final List<HeartRateSample>? heartRateSamples;
  final HeartRateZones? heartRateZones;
  final double? avgHeartRateBpm;
  final double? maxHeartRateBpm;
  final double? activeEnergyKcal;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final double? elevationLossMeters;
  final double? powerWattsAvg;
  final double? normalizedPowerWatts;
  final double? steps;
  final double? runCount;

  const WorkoutSessionInput({
    required this.id,
    required this.athleteId,
    required this.date,
    this.startTime,
    this.endTime,
    required this.sportType,
    required this.durationMinutes,
    this.rpe,
    this.heartRateSamples,
    this.heartRateZones,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    this.activeEnergyKcal,
    this.distanceMeters,
    this.elevationGainMeters,
    this.elevationLossMeters,
    this.powerWattsAvg,
    this.normalizedPowerWatts,
    this.steps,
    this.runCount,
  });
}

class AthleteStrainProfile {
  final String athleteId;
  final double? maxHeartRateBpm;
  final double? restingHeartRateEstimateBpm;
  final double? bodyMassKg;

  const AthleteStrainProfile({
    required this.athleteId,
    this.maxHeartRateBpm,
    this.restingHeartRateEstimateBpm,
    this.bodyMassKg,
  });
}

class HistoricalDailyStrainLoad {
  final String date;
  final double? cardioLoadAU;
  final double? rpeLoadAU;
  final double? externalMechanicalLoadAU;
  final double totalDurationMinutes;
  final int sessionCount;

  const HistoricalDailyStrainLoad({
    required this.date,
    this.cardioLoadAU,
    this.rpeLoadAU,
    this.externalMechanicalLoadAU,
    required this.totalDurationMinutes,
    required this.sessionCount,
  });
}

class SessionStrainResult {
  final String sessionId;
  final StrainSportCategory sportCategory;
  final double durationMinutes;
  final double? cardioLoadAU;
  final double? rpeLoadAU;
  final double? externalMechanicalLoadAU;
  final double heartRateCoverage;
  final String? cardioMethod;
  final String? rpeMethod;
  final String? externalMechanicalMethod;
  final double confidence;
  final List<String> warnings;

  const SessionStrainResult({
    required this.sessionId,
    required this.sportCategory,
    required this.durationMinutes,
    this.cardioLoadAU,
    this.rpeLoadAU,
    this.externalMechanicalLoadAU,
    required this.heartRateCoverage,
    this.cardioMethod,
    this.rpeMethod,
    this.externalMechanicalMethod,
    required this.confidence,
    required this.warnings,
  });
}

class DailyStrainResult {
  final double? score;
  final StrainScoreStatus status;
  final double confidence;
  final Map<String, dynamic> components;
  final List<String> warnings;

  const DailyStrainResult({
    required this.score,
    required this.status,
    required this.confidence,
    required this.components,
    required this.warnings,
  });

  String get statusCode => status.code;
}

class Nap {
  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final double durationMinutes;

  const Nap({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.durationMinutes,
  });
}

class DailyWearableData {
  final String date;
  final double? totalSleepTimeMinutes;
  final double? deepSleepMinutes;
  final double? remSleepMinutes;
  final double? timeInBedMinutes;
  final DateTime? sleepOnsetTimestamp;
  final DateTime? sleepWakeTimestamp;
  final List<Nap>? naps;
  final double? restingHeartRateBpm;
  final double? hrvRmssdMs;
  final String hrvMetric;
  final double? skinTemperatureCelsius;
  final String temperatureMetric;
  final double? respiratoryRate;
  final double? spo2Percent;
  final double? previousDayStrainScore;
  final int? previousDayWorkoutCount;

  const DailyWearableData({
    required this.date,
    this.totalSleepTimeMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.timeInBedMinutes,
    this.sleepOnsetTimestamp,
    this.sleepWakeTimestamp,
    this.naps,
    this.restingHeartRateBpm,
    this.hrvRmssdMs,
    this.hrvMetric = 'unknown',
    this.skinTemperatureCelsius,
    this.temperatureMetric = 'unknown',
    this.respiratoryRate,
    this.spo2Percent,
    this.previousDayStrainScore,
    this.previousDayWorkoutCount,
  });

  DailyWearableData copyWith({
    double? restingHeartRateBpm,
    double? hrvRmssdMs,
    String? hrvMetric,
    double? skinTemperatureCelsius,
    String? temperatureMetric,
  }) {
    return DailyWearableData(
      date: date,
      totalSleepTimeMinutes: totalSleepTimeMinutes,
      deepSleepMinutes: deepSleepMinutes,
      remSleepMinutes: remSleepMinutes,
      timeInBedMinutes: timeInBedMinutes,
      sleepOnsetTimestamp: sleepOnsetTimestamp,
      sleepWakeTimestamp: sleepWakeTimestamp,
      naps: naps,
      restingHeartRateBpm: restingHeartRateBpm ?? this.restingHeartRateBpm,
      hrvRmssdMs: hrvRmssdMs ?? this.hrvRmssdMs,
      hrvMetric: hrvMetric ?? this.hrvMetric,
      skinTemperatureCelsius:
          skinTemperatureCelsius ?? this.skinTemperatureCelsius,
      temperatureMetric: temperatureMetric ?? this.temperatureMetric,
      respiratoryRate: respiratoryRate,
      spo2Percent: spo2Percent,
      previousDayStrainScore: previousDayStrainScore,
      previousDayWorkoutCount: previousDayWorkoutCount,
    );
  }
}

typedef HistoricalDailyData = List<DailyWearableData>;

class ScoreResult {
  final double? score;
  final ScoreStatus status;
  final double confidence;
  final Map<String, dynamic> components;
  final List<String> warnings;

  const ScoreResult({
    required this.score,
    required this.status,
    required this.confidence,
    required this.components,
    required this.warnings,
  });

  String get statusCode => status.code;
}

class DailySleepNeedResult {
  final double valueMinutes;
  final double personalBaselineMinutes;
  final double sleepDebtMinutes;
  final double dailyStrainAdjustmentMinutes;
  final double napsDeductionMinutes;
  final double confidence;
  final List<String> warnings;

  const DailySleepNeedResult({
    required this.valueMinutes,
    required this.personalBaselineMinutes,
    required this.sleepDebtMinutes,
    required this.dailyStrainAdjustmentMinutes,
    required this.napsDeductionMinutes,
    required this.confidence,
    required this.warnings,
  });
}

class RecoveryAndSleepResult {
  final ScoreResult sleepScore;
  final ScoreResult recoveryScore;
  final DailySleepNeedResult dailySleepNeed;
  final String appliedConfigVersion;

  const RecoveryAndSleepResult({
    required this.sleepScore,
    required this.recoveryScore,
    required this.dailySleepNeed,
    required this.appliedConfigVersion,
  });
}
