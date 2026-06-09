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
  final String timezone;

  const AthleteProfile({
    required this.athleteId,
    this.sex = Sex.unknown,
    this.isLutealPhase = false,
    required this.timezone,
  });
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
  final List<Nap>? naps;
  final double? restingHeartRateBpm;
  final double? hrvRmssdMs;
  final double? skinTemperatureCelsius;
  final double? respiratoryRate;
  final double? spo2Percent;
  final double? previousDayStrainScore;

  const DailyWearableData({
    required this.date,
    this.totalSleepTimeMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.timeInBedMinutes,
    this.sleepOnsetTimestamp,
    this.naps,
    this.restingHeartRateBpm,
    this.hrvRmssdMs,
    this.skinTemperatureCelsius,
    this.respiratoryRate,
    this.spo2Percent,
    this.previousDayStrainScore,
  });

  DailyWearableData copyWith({
    double? restingHeartRateBpm,
    double? hrvRmssdMs,
    double? skinTemperatureCelsius,
  }) {
    return DailyWearableData(
      date: date,
      totalSleepTimeMinutes: totalSleepTimeMinutes,
      deepSleepMinutes: deepSleepMinutes,
      remSleepMinutes: remSleepMinutes,
      timeInBedMinutes: timeInBedMinutes,
      sleepOnsetTimestamp: sleepOnsetTimestamp,
      naps: naps,
      restingHeartRateBpm: restingHeartRateBpm ?? this.restingHeartRateBpm,
      hrvRmssdMs: hrvRmssdMs ?? this.hrvRmssdMs,
      skinTemperatureCelsius:
          skinTemperatureCelsius ?? this.skinTemperatureCelsius,
      respiratoryRate: respiratoryRate,
      spo2Percent: spo2Percent,
      previousDayStrainScore: previousDayStrainScore,
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
