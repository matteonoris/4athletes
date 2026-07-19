import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = AthleteProfile(
    athleteId: 'recovery-v2-athlete',
    sex: Sex.female,
    timezone: 'Europe/Rome',
  );

  group('robust personal baseline', () {
    test('median and MAD resist an isolated outlier', () {
      final stats = medianAndRobustStandardDeviation([10, 10, 11, 100], 1);

      expect(stats, isNotNull);
      expect(stats!.median, 10.5);
      expect(stats.medianAbsoluteDeviation, 0.5);
      expect(stats.robustStandardDeviation, 1);
    });

    test('30 placeholder rows remain in calibration', () {
      final history = List.generate(
        30,
        (index) => DailyWearableData(date: _date(index + 1)),
      );
      final result = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        history,
        _sleep(80),
      );

      expect(result.score, isNull);
      expect(result.status, ScoreStatus.calibrationPhase);
      expect(result.components['validAutonomicHistoryDays'], 0);
    });

    test('history is sorted and duplicate dates are replaced', () {
      final unique = _history(7);
      final history = [
        unique[4],
        unique[1],
        unique[6],
        unique[0],
        unique[3],
        unique[2],
        unique[5],
        _day(unique[3].date, restingHeartRateBpm: 52),
      ];
      final result = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        history,
        _sleep(80),
      );

      expect(result.score, isNotNull);
      expect(result.components['canonicalHistoryDays'], 7);
      expect(result.components['historyDays'], 7);
    });

    test('confidence increases from seven to twenty-eight valid nights', () {
      final provisional = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        _history(7),
        _sleep(80),
      );
      final full = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        _history(28),
        _sleep(80),
      );

      expect(provisional.score, isNotNull);
      expect(full.score, isNotNull);
      expect(provisional.confidence, lessThan(full.confidence));
      expect(provisional.confidence, closeTo(0.25, 0.000001));
      expect(full.confidence, 1);
    });
  });

  group('metric semantics and physiological direction', () {
    test('unknown HRV provenance is explicit', () {
      final result = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        _history(7),
        _sleep(80),
      );

      expect(result.score, isNotNull);
      expect(result.warnings, contains('hrv_metric_provenance_unknown'));
      expect(_details(result, 'hrv')['hrvMetric'], 'unknown');
    });

    test('HRV baselines never mix RMSSD and SDNN', () {
      final history = <DailyWearableData>[
        ..._history(7, hrvMetric: 'rmssd', hrvStart: 50),
        ..._history(
          7,
          startDay: 8,
          hrvMetric: 'sdnn',
          hrvStart: 90,
        ),
      ];
      final result = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', hrvRmssdMs: 60, hrvMetric: 'rmssd'),
        history,
        _sleep(80),
      );
      final details = _details(result, 'hrv');

      expect(result.score, isNotNull);
      expect(details['hrvMetric'], 'rmssd');
      expect(details['validHistoryDays'], 7);
    });

    test('favorable HRV and RHR contributions are capped', () {
      final history = _history(
        7,
        hrvMetric: 'rmssd',
        hrvStart: 50,
        varyHrv: false,
      );
      final result = calculateRecoveryScoreResult(
        profile,
        _day(
          '2026-02-01',
          hrvRmssdMs: 250,
          hrvMetric: 'rmssd',
          restingHeartRateBpm: 40,
        ),
        history,
        _sleep(80),
      );

      expect(_componentValue(result, 'hrv'), 1.5);
      expect(_componentValue(result, 'restingHeartRate'), 1.5);
    });

    test('skin temperature delta is accepted and retains its metric', () {
      final history = _history(
        7,
        temperature: 0,
        temperatureMetric: 'skin_temperature_delta_celsius',
      );
      final result = calculateRecoveryScoreResult(
        profile,
        _day(
          '2026-02-01',
          skinTemperatureCelsius: 1,
          temperatureMetric: 'skin_temperature_delta_celsius',
        ),
        history,
        _sleep(80),
      );
      final details = _details(result, 'skinTemperature');

      expect(_used(result, 'skinTemperature'), isTrue);
      expect(details['temperatureMetric'], 'skin_temperature_delta_celsius');
      expect(_componentValue(result, 'skinTemperature'), lessThan(0));
    });

    test('temperature only penalizes high anomalies after the deadband', () {
      final history = _history(7, temperature: 36.5);
      final high = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', skinTemperatureCelsius: 37.0),
        history,
        _sleep(80),
      );
      final low = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', skinTemperatureCelsius: 36.0),
        history,
        _sleep(80),
      );

      expect(_componentValue(high, 'skinTemperature'), lessThan(0));
      expect(_componentValue(low, 'skinTemperature'), 0);
    });

    test('respiratory rate penalizes both high and low anomalies', () {
      final history = _history(7, respiratoryRate: 14);
      final high = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', respiratoryRate: 16),
        history,
        _sleep(80),
      );
      final low = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', respiratoryRate: 12),
        history,
        _sleep(80),
      );

      expect(_componentValue(high, 'respiratoryRate'), lessThan(0));
      expect(_componentValue(low, 'respiratoryRate'), lessThan(0));
      expect(
        _componentValue(high, 'respiratoryRate'),
        closeTo(_componentValue(low, 'respiratoryRate'), 0.000001),
      );
    });

    test('SpO2 only penalizes low anomalies', () {
      final history = _history(7, spo2: 98);
      final high = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', spo2Percent: 99),
        history,
        _sleep(80),
      );
      final low = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01', spo2Percent: 97),
        history,
        _sleep(80),
      );

      expect(_componentValue(high, 'spo2'), 0);
      expect(_componentValue(low, 'spo2'), lessThan(0));
    });

    test('sleep contribution uses an absolute target, not poor history', () {
      final poorSleepHistory = _history(7, totalSleepMinutes: 240);
      final result = calculateRecoveryScoreResult(
        profile,
        _day('2026-02-01'),
        poorSleepHistory,
        _sleep(60),
      );
      final details = _details(result, 'sleep');

      expect(details['normalization'], 'absolute');
      expect(_componentValue(result, 'sleep'), -1);
    });
  });

  group('minimum evidence requirements', () {
    test('today requires at least one usable autonomic component', () {
      final result = calculateRecoveryScoreResult(
        profile,
        _day(
          '2026-02-01',
          restingHeartRateBpm: null,
          hrvRmssdMs: null,
        ),
        _history(7),
        _sleep(80),
      );

      expect(result.score, isNull);
      expect(result.status, ScoreStatus.insufficientData);
      expect(
        result.warnings,
        contains('recovery_autonomic_component_required'),
      );
    });

    test('available weight below threshold does not produce a score', () {
      final history = _history(
        7,
        includeRhr: false,
        includeOptionalMetrics: false,
      );
      final result = calculateRecoveryScoreResult(
        profile,
        _day(
          '2026-02-01',
          restingHeartRateBpm: null,
          skinTemperatureCelsius: null,
          respiratoryRate: null,
          spo2Percent: null,
        ),
        history,
        _sleep(null),
      );

      expect(result.score, isNull);
      expect(result.components['availableWeight'], closeTo(0.30, 0.000001));
      expect(
        result.warnings,
        contains('recovery_available_weight_below_minimum'),
      );
    });

    test('luteal phase is context only when fixed adjustment is disabled', () {
      const lutealProfile = AthleteProfile(
        athleteId: 'recovery-v2-athlete',
        sex: Sex.female,
        isLutealPhase: true,
        timezone: 'Europe/Rome',
      );
      final history = _history(7);
      final today = _day('2026-02-01');
      final withoutContext = calculateRecoveryScoreResult(
        profile,
        today,
        history,
        _sleep(80),
      );
      final withContext = calculateRecoveryScoreResult(
        lutealProfile,
        today,
        history,
        _sleep(80),
      );

      expect(withContext.score, closeTo(withoutContext.score!, 0.000001));
      expect(
        withContext.warnings,
        contains('luteal_phase_context_only_fixed_adjustment_disabled'),
      );
    });
  });
}

ScoreResult _sleep(double? score) => ScoreResult(
      score: score,
      status: score == null ? ScoreStatus.insufficientData : ScoreStatus.ok,
      confidence: score == null ? 0 : 1,
      components: const {},
      warnings: const [],
    );

List<DailyWearableData> _history(
  int count, {
  int startDay = 1,
  String hrvMetric = 'unknown',
  double hrvStart = 70,
  bool varyHrv = true,
  bool includeRhr = true,
  bool includeOptionalMetrics = true,
  double temperature = 36.5,
  String temperatureMetric = 'unknown',
  double respiratoryRate = 14,
  double spo2 = 98,
  double totalSleepMinutes = 480,
}) {
  return List.generate(count, (index) {
    return _day(
      _date(startDay + index),
      totalSleepTimeMinutes: totalSleepMinutes,
      restingHeartRateBpm: includeRhr ? 50 : null,
      hrvRmssdMs: hrvStart + (varyHrv ? index : 0),
      hrvMetric: hrvMetric,
      skinTemperatureCelsius: includeOptionalMetrics ? temperature : null,
      temperatureMetric: temperatureMetric,
      respiratoryRate: includeOptionalMetrics ? respiratoryRate : null,
      spo2Percent: includeOptionalMetrics ? spo2 : null,
    );
  });
}

DailyWearableData _day(
  String date, {
  double? totalSleepTimeMinutes = 480,
  double? restingHeartRateBpm = 50,
  double? hrvRmssdMs = 70,
  String hrvMetric = 'unknown',
  double? skinTemperatureCelsius = 36.5,
  String temperatureMetric = 'unknown',
  double? respiratoryRate = 14,
  double? spo2Percent = 98,
}) {
  return DailyWearableData(
    date: date,
    totalSleepTimeMinutes: totalSleepTimeMinutes,
    restingHeartRateBpm: restingHeartRateBpm,
    hrvRmssdMs: hrvRmssdMs,
    hrvMetric: hrvMetric,
    skinTemperatureCelsius: skinTemperatureCelsius,
    temperatureMetric: temperatureMetric,
    respiratoryRate: respiratoryRate,
    spo2Percent: spo2Percent,
  );
}

String _date(int day) => '2026-01-${day.toString().padLeft(2, '0')}';

Map<String, dynamic> _component(ScoreResult result, String key) =>
    Map<String, dynamic>.from(result.components[key] as Map);

Map<String, dynamic> _details(ScoreResult result, String key) =>
    Map<String, dynamic>.from(_component(result, key)['details'] as Map);

double _componentValue(ScoreResult result, String key) =>
    (_component(result, key)['value'] as num).toDouble();

bool _used(ScoreResult result, String key) =>
    _component(result, key)['used'] as bool;
