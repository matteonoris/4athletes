class AlgorithmConfig {
  final String version;
  final ScoreConfig score;
  final ConfidenceConfig confidence;
  final HistoryConfig history;
  final ZScoreConfig zScore;
  final SleepNeedConfig sleepNeed;
  final SleepScoreConfig sleepScore;
  final RecoveryScoreConfig recoveryScore;
  final StrainScoreConfig strainScore;
  final PhysiologyConfig physiology;
  final TimeConfig time;

  const AlgorithmConfig({
    required this.version,
    required this.score,
    required this.confidence,
    required this.history,
    required this.zScore,
    required this.sleepNeed,
    required this.sleepScore,
    required this.recoveryScore,
    required this.strainScore,
    required this.physiology,
    required this.time,
  });
}

class ScoreConfig {
  final double min;
  final double max;
  final double neutralRecoveryScore;
  final double fallbackSleepScoreRange;
  final double fallbackSleepZScale;

  const ScoreConfig({
    required this.min,
    required this.max,
    required this.neutralRecoveryScore,
    required this.fallbackSleepScoreRange,
    required this.fallbackSleepZScale,
  });
}

class ConfidenceConfig {
  final double min;
  final double max;
  final double shortHistoryMultiplier;
  final double missingInputMultiplier;
  final double partialBaselineMultiplier;
  final double fallbackBaselineMultiplier;
  final double fallbackSleepBaselineMultiplier;

  const ConfidenceConfig({
    required this.min,
    required this.max,
    required this.shortHistoryMultiplier,
    required this.missingInputMultiplier,
    required this.partialBaselineMultiplier,
    required this.fallbackBaselineMultiplier,
    required this.fallbackSleepBaselineMultiplier,
  });
}

class HistoryConfig {
  final int rollingWindowDays;
  final int minCalibrationDays;
  final int sleepDebtWindowDays;
  final int sleepScoreBaselineMinDays;

  const HistoryConfig({
    required this.rollingWindowDays,
    required this.minCalibrationDays,
    required this.sleepDebtWindowDays,
    required this.sleepScoreBaselineMinDays,
  });
}

class ZScoreConfig {
  final double lowerClip;
  final double upperClip;
  final MinStdDevConfig minStdDev;

  const ZScoreConfig({
    required this.lowerClip,
    required this.upperClip,
    required this.minStdDev,
  });
}

class MinStdDevConfig {
  final double restingHeartRateBpm;
  final double respiratoryRate;
  final double spo2Percent;
  final double skinTemperatureCelsius;
  final double lnHrvRmssd;
  final double sleepScore;

  const MinStdDevConfig({
    required this.restingHeartRateBpm,
    required this.respiratoryRate,
    required this.spo2Percent,
    required this.skinTemperatureCelsius,
    required this.lnHrvRmssd,
    required this.sleepScore,
  });
}

class SleepNeedConfig {
  final double defaultSleepBaselineMinutes;
  final MetricRange validBaselineSleepMinutes;
  final int minValidBaselineNights;
  final int partialBaselineMinNights;
  final double sleepDebtDecayLambda;
  final double maxSleepDebtMinutes;
  final double maxStrainSleepNeedMinutes;
  final double maxNapsDeductionMinutes;
  final double minDailySleepNeedMinutes;
  final double maxDailySleepNeedMinutes;

  const SleepNeedConfig({
    required this.defaultSleepBaselineMinutes,
    required this.validBaselineSleepMinutes,
    required this.minValidBaselineNights,
    required this.partialBaselineMinNights,
    required this.sleepDebtDecayLambda,
    required this.maxSleepDebtMinutes,
    required this.maxStrainSleepNeedMinutes,
    required this.maxNapsDeductionMinutes,
    required this.minDailySleepNeedMinutes,
    required this.maxDailySleepNeedMinutes,
  });
}

class SleepScoreConfig {
  final SleepScoreWeights weights;
  final double restorativeRatioTarget;
  final double circadianToleranceMinutes;
  final double circadianPenaltyStepMinutes;
  final double circadianPenaltyPerStep;

  const SleepScoreConfig({
    required this.weights,
    required this.restorativeRatioTarget,
    required this.circadianToleranceMinutes,
    required this.circadianPenaltyStepMinutes,
    required this.circadianPenaltyPerStep,
  });
}

class SleepScoreWeights {
  final double duration;
  final double architecture;
  final double circadianRegularity;
  final double efficiency;

  const SleepScoreWeights({
    required this.duration,
    required this.architecture,
    required this.circadianRegularity,
    required this.efficiency,
  });
}

class RecoveryScoreConfig {
  final RecoveryScoreWeights weights;
  final double sigmoidK;
  final double sigmoidBias;
  final LutealPhaseAdjustment lutealPhaseAdjustment;

  const RecoveryScoreConfig({
    required this.weights,
    required this.sigmoidK,
    required this.sigmoidBias,
    required this.lutealPhaseAdjustment,
  });
}

class RecoveryScoreWeights {
  final double hrv;
  final double restingHeartRate;
  final double skinTemperature;
  final double sleep;
  final double respiratoryRate;
  final double spo2;

  const RecoveryScoreWeights({
    required this.hrv,
    required this.restingHeartRate,
    required this.skinTemperature,
    required this.sleep,
    required this.respiratoryRate,
    required this.spo2,
  });
}

class LutealPhaseAdjustment {
  final double restingHeartRateSubtractBpm;
  final double skinTemperatureSubtractCelsius;
  final double hrvMultiplier;

  const LutealPhaseAdjustment({
    required this.restingHeartRateSubtractBpm,
    required this.skinTemperatureSubtractCelsius,
    required this.hrvMultiplier,
  });
}

class StrainScoreConfig {
  final int historyWindowDays;
  final int minPersonalBaselineDays;
  final int fullPersonalBaselineDays;
  final double cardioExponent;
  final double minHrCoverageForFullConfidence;
  final double minHrCoverageToUseSamples;
  final double defaultMaxHeartRateBpm;
  final double defaultRestingHeartRateEstimateBpm;
  final double minPercentileGapAbsolute;
  final double minPercentileGapRatio;
  final double missingComponentConfidenceMultiplier;
  final double partialHrConfidenceMultiplier;
  final double lowHrQualityScore;
  final double partialBaselineConfidence;
  final double coldStartBaselineConfidence;
  final double noTrainingConfidence;
  final double missingStrainWorkoutFallbackScore;
  final Map<String, double> cardioZoneMultipliers;
  final Map<String, double> sportCardioFallbackMultipliers;
  final Map<String, double> sportImpactMultipliers;
  final Map<String, StrainComponentWeights> componentWeights;
  final StrainAbsoluteAnchors absoluteAnchors;

  const StrainScoreConfig({
    required this.historyWindowDays,
    required this.minPersonalBaselineDays,
    required this.fullPersonalBaselineDays,
    required this.cardioExponent,
    required this.minHrCoverageForFullConfidence,
    required this.minHrCoverageToUseSamples,
    required this.defaultMaxHeartRateBpm,
    required this.defaultRestingHeartRateEstimateBpm,
    required this.minPercentileGapAbsolute,
    required this.minPercentileGapRatio,
    required this.missingComponentConfidenceMultiplier,
    required this.partialHrConfidenceMultiplier,
    required this.lowHrQualityScore,
    required this.partialBaselineConfidence,
    required this.coldStartBaselineConfidence,
    required this.noTrainingConfidence,
    required this.missingStrainWorkoutFallbackScore,
    required this.cardioZoneMultipliers,
    required this.sportCardioFallbackMultipliers,
    required this.sportImpactMultipliers,
    required this.componentWeights,
    required this.absoluteAnchors,
  });
}

class StrainComponentWeights {
  final double cardio;
  final double rpe;
  final double externalMechanical;

  const StrainComponentWeights({
    required this.cardio,
    required this.rpe,
    required this.externalMechanical,
  });
}

class StrainAbsoluteAnchors {
  final StrainComponentAnchors cardio;
  final StrainComponentAnchors rpe;
  final StrainComponentAnchors externalMechanical;

  const StrainAbsoluteAnchors({
    required this.cardio,
    required this.rpe,
    required this.externalMechanical,
  });
}

class StrainComponentAnchors {
  final double p50;
  final double p90;
  final double p95;

  const StrainComponentAnchors({
    required this.p50,
    required this.p90,
    required this.p95,
  });
}

class PhysiologyConfig {
  final MetricRange totalSleepTimeMinutes;
  final MetricRange sleepStageMinutes;
  final MetricRange timeInBedMinutes;
  final MetricRange restingHeartRateBpm;
  final MetricRange hrvRmssdMs;
  final MetricRange skinTemperatureCelsius;
  final MetricRange respiratoryRate;
  final MetricRange spo2Percent;
  final MetricRange previousDayStrainScore;

  const PhysiologyConfig({
    required this.totalSleepTimeMinutes,
    required this.sleepStageMinutes,
    required this.timeInBedMinutes,
    required this.restingHeartRateBpm,
    required this.hrvRmssdMs,
    required this.skinTemperatureCelsius,
    required this.respiratoryRate,
    required this.spo2Percent,
    required this.previousDayStrainScore,
  });
}

class MetricRange {
  final double min;
  final double max;
  final bool minExclusive;

  const MetricRange({
    required this.min,
    required this.max,
    this.minExclusive = false,
  });

  bool contains(num? value) {
    if (value == null || !value.isFinite) return false;
    final lowerOk = minExclusive ? value > min : value >= min;
    return lowerOk && value <= max;
  }
}

class TimeConfig {
  final int minutesPerHour;
  final int hoursPerDay;
  final int minutesPerDay;

  const TimeConfig({
    required this.minutesPerHour,
    required this.hoursPerDay,
    required this.minutesPerDay,
  });
}

const defaultAlgorithmConfig = AlgorithmConfig(
  version: 'wellness-scoring-v1.1.0',
  score: ScoreConfig(
    min: 0,
    max: 100,
    neutralRecoveryScore: 50,
    fallbackSleepScoreRange: 50,
    fallbackSleepZScale: 3,
  ),
  confidence: ConfidenceConfig(
    min: 0,
    max: 1,
    shortHistoryMultiplier: 0.9,
    missingInputMultiplier: 0.9,
    partialBaselineMultiplier: 0.8,
    fallbackBaselineMultiplier: 0.55,
    fallbackSleepBaselineMultiplier: 0.8,
  ),
  history: HistoryConfig(
    rollingWindowDays: 30,
    minCalibrationDays: 4,
    sleepDebtWindowDays: 14,
    sleepScoreBaselineMinDays: 4,
  ),
  zScore: ZScoreConfig(
    lowerClip: -3,
    upperClip: 3,
    minStdDev: MinStdDevConfig(
      restingHeartRateBpm: 0.5,
      respiratoryRate: 0.2,
      spo2Percent: 0.2,
      skinTemperatureCelsius: 0.05,
      lnHrvRmssd: 0.05,
      sleepScore: 3,
    ),
  ),
  sleepNeed: SleepNeedConfig(
    defaultSleepBaselineMinutes: 480,
    validBaselineSleepMinutes: MetricRange(min: 180, max: 720),
    minValidBaselineNights: 7,
    partialBaselineMinNights: 4,
    sleepDebtDecayLambda: 0.25,
    maxSleepDebtMinutes: 90,
    maxStrainSleepNeedMinutes: 45,
    maxNapsDeductionMinutes: 120,
    minDailySleepNeedMinutes: 360,
    maxDailySleepNeedMinutes: 660,
  ),
  sleepScore: SleepScoreConfig(
    weights: SleepScoreWeights(
      duration: 0.40,
      architecture: 0.20,
      circadianRegularity: 0.25,
      efficiency: 0.15,
    ),
    restorativeRatioTarget: 0.40,
    circadianToleranceMinutes: 30,
    circadianPenaltyStepMinutes: 30,
    circadianPenaltyPerStep: 15,
  ),
  recoveryScore: RecoveryScoreConfig(
    weights: RecoveryScoreWeights(
      hrv: 0.35,
      restingHeartRate: 0.20,
      skinTemperature: 0.15,
      sleep: 0.15,
      respiratoryRate: 0.10,
      spo2: 0.05,
    ),
    sigmoidK: 0.8,
    sigmoidBias: 1.06,
    lutealPhaseAdjustment: LutealPhaseAdjustment(
      restingHeartRateSubtractBpm: 2,
      skinTemperatureSubtractCelsius: 0.4,
      hrvMultiplier: 1.10,
    ),
  ),
  strainScore: StrainScoreConfig(
    historyWindowDays: 42,
    minPersonalBaselineDays: 7,
    fullPersonalBaselineDays: 21,
    cardioExponent: 1.92,
    minHrCoverageForFullConfidence: 0.70,
    minHrCoverageToUseSamples: 0.30,
    defaultMaxHeartRateBpm: 190,
    defaultRestingHeartRateEstimateBpm: 50,
    minPercentileGapAbsolute: 10,
    minPercentileGapRatio: 0.15,
    missingComponentConfidenceMultiplier: 0.85,
    partialHrConfidenceMultiplier: 0.80,
    lowHrQualityScore: 0.35,
    partialBaselineConfidence: 0.75,
    coldStartBaselineConfidence: 0.50,
    noTrainingConfidence: 1,
    missingStrainWorkoutFallbackScore: 30,
    cardioZoneMultipliers: {
      'z1': 1,
      'z2': 2,
      'z3': 3,
      'z4': 5,
      'z5': 8,
    },
    sportCardioFallbackMultipliers: {
      'mobility': 0.8,
      'cycling': 2.5,
      'swimming': 2.8,
      'endurance_generic': 2.4,
      'running': 3.0,
      'football': 3.0,
      'strength': 1.5,
      'sprint': 2.6,
      'plyometrics': 2.2,
      'alpine_skiing_training': 2.4,
      'alpine_skiing_race': 2.8,
      'team_sport': 2.8,
      'unknown': 2.0,
    },
    sportImpactMultipliers: {
      'mobility': 0.3,
      'cycling': 0.5,
      'swimming': 0.5,
      'endurance_generic': 0.7,
      'running': 0.9,
      'football': 1.0,
      'strength': 0.9,
      'sprint': 1.2,
      'plyometrics': 1.2,
      'alpine_skiing_training': 1.15,
      'alpine_skiing_race': 1.3,
      'team_sport': 1.0,
      'unknown': 0.7,
    },
    componentWeights: {
      'default': StrainComponentWeights(
        cardio: 0.40,
        rpe: 0.35,
        externalMechanical: 0.25,
      ),
      'endurance': StrainComponentWeights(
        cardio: 0.55,
        rpe: 0.30,
        externalMechanical: 0.15,
      ),
      'team_sport': StrainComponentWeights(
        cardio: 0.40,
        rpe: 0.35,
        externalMechanical: 0.25,
      ),
      'strength': StrainComponentWeights(
        cardio: 0.15,
        rpe: 0.45,
        externalMechanical: 0.40,
      ),
      'sprint_plyometrics': StrainComponentWeights(
        cardio: 0.15,
        rpe: 0.40,
        externalMechanical: 0.45,
      ),
      'alpine_skiing_training': StrainComponentWeights(
        cardio: 0.30,
        rpe: 0.40,
        externalMechanical: 0.30,
      ),
      'alpine_skiing_race': StrainComponentWeights(
        cardio: 0.25,
        rpe: 0.40,
        externalMechanical: 0.35,
      ),
      'mobility': StrainComponentWeights(
        cardio: 0.10,
        rpe: 0.50,
        externalMechanical: 0.40,
      ),
    },
    absoluteAnchors: StrainAbsoluteAnchors(
      cardio: StrainComponentAnchors(p50: 90, p90: 260, p95: 360),
      rpe: StrainComponentAnchors(p50: 300, p90: 700, p95: 900),
      externalMechanical: StrainComponentAnchors(p50: 35, p90: 110, p95: 160),
    ),
  ),
  physiology: PhysiologyConfig(
    totalSleepTimeMinutes: MetricRange(min: 0, max: 1440, minExclusive: true),
    sleepStageMinutes: MetricRange(min: 0, max: 1440),
    timeInBedMinutes: MetricRange(min: 0, max: 1440, minExclusive: true),
    restingHeartRateBpm: MetricRange(min: 25, max: 220),
    hrvRmssdMs: MetricRange(min: 0, max: 300, minExclusive: true),
    skinTemperatureCelsius: MetricRange(min: 25, max: 45),
    respiratoryRate: MetricRange(min: 5, max: 60),
    spo2Percent: MetricRange(min: 50, max: 100),
    previousDayStrainScore: MetricRange(min: 0, max: 100),
  ),
  time: TimeConfig(
    minutesPerHour: 60,
    hoursPerDay: 24,
    minutesPerDay: 1440,
  ),
);
