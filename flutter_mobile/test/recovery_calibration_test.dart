import 'package:flutter_mobile/utils/metrics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = AthleteProfile(athleteId: 'recovery-test', timezone: 'UTC');

void main() {
  test(
      'habitual physiology is moderate; concordant favorable signals can be high',
      () {
    expect(_score(_day(28), _sleep(75)).score, closeTo(65, 1e-8));
    expect(
        _score(_day(28, hrv: 90, rhr: 47), _sleep(100)).score, greaterThan(85));
    expect(_score(_day(28, hrv: 50, rhr: 54), _sleep(40)).score, lessThan(25));
  });

  test('sleep keeps its absolute anchor and degrades recovery monotonically',
      () {
    var previous = -1.0;
    for (var sleepScore = 0.0; sleepScore <= 100; sleepScore += 5) {
      final result = _score(_day(28), _sleep(sleepScore));
      expect(result.score, inInclusiveRange(0, 100));
      expect(result.score, greaterThanOrEqualTo(previous));
      previous = result.score!;
    }
    expect(_score(_day(28), _sleep(40)).score, lessThan(55));
  });

  test('high HRV cannot mask elevated resting heart rate', () {
    final result = _score(_day(28, hrv: 90, rhr: 53), _sleep(75));
    expect(result.components['hrv']['value'], 0);
    expect(
        result.components['hrv']['details']['contributionBeforeConflict'], 1.5);
    expect(result.components['restingHeartRate']['value'], -2);
    expect(result.score, lessThan(60));
    expect(result.warnings,
        contains('conflicting_autonomic_signals_positive_credit_reduced'));
  });

  test('low resting heart rate cannot mask suppressed HRV', () {
    final result = _score(_day(28, hrv: 50, rhr: 47), _sleep(75));
    expect(result.components['restingHeartRate']['value'], 0);
    expect(result.components['hrv']['value'], lessThan(0));
  });

  test('ordinary autonomic noise does not suppress a favorable contribution',
      () {
    final result = _score(_day(28, hrv: 90, rhr: 50.5), _sleep(75));
    expect(result.components['hrv']['value'], 1.5);
  });

  test(
      'partial sleep confidence propagates without inventing a different sleep score',
      () {
    final full = _score(_day(28), _sleep(60));
    final partial = _score(_day(28), _sleep(60, confidence: 0.4));
    expect(partial.score, full.score);
    expect(partial.confidence, closeTo(full.confidence - 0.15, 1e-8));
    expect(partial.status, ScoreStatus.partialData);
    expect(partial.components['componentConfidences']['sleep'], 0.4);
    expect(partial.warnings, contains('sleep_component_partial_confidence'));
  });

  test('invalid sleep confidence or status excludes its contribution', () {
    for (final confidence in [0.0, double.nan, double.infinity, 1.1]) {
      final result = _score(_day(28), _sleep(100, confidence: confidence));
      expect(result.components['sleep']['used'], isFalse);
      expect(result.confidence.isFinite, isTrue);
    }
    final result = _score(
        _day(28),
        const ScoreResult(
            score: 95,
            status: ScoreStatus.insufficientData,
            confidence: 0.8,
            components: {},
            warnings: []));
    expect(result.components['sleep']['used'], isFalse);
  });

  test('each metric needs its own history for full confidence', () {
    final history = List.generate(28, (i) => _day(i, hrv: i < 21 ? null : 70));
    final result = _score(_day(28), _sleep(75), history: history);
    expect(result.components['validAutonomicHistoryDays'], 28);
    expect(result.components['componentConfidences']['hrv'], 0.25);
    expect(result.confidence, closeTo(0.775, 1e-8));
    expect(result.status, ScoreStatus.partialData);
  });

  test('future and old history cannot calibrate or change recovery', () {
    final history = List.generate(28, _day);
    final baseline = _score(_day(28), _sleep(75), history: history);
    final noisy = _score(_day(28), _sleep(75), history: [
      ...history.reversed,
      _day(-1, hrv: 40),
      _day(28, hrv: 40),
      _day(29, hrv: 40),
      history[1],
      const DailyWearableData(date: 'invalid', restingHeartRateBpm: 60),
    ]);
    expect(noisy.score, baseline.score);
    expect(noisy.confidence, baseline.confidence);
    final stale = _score(_day(60), _sleep(75), history: history);
    expect(stale.score, isNull);
    expect(stale.status, ScoreStatus.calibrationPhase);
  });

  test('same physiology is relative to personal history, never another athlete',
      () {
    final habitual = _score(_day(28, hrv: 50, rhr: 54), _sleep(75),
        history: List.generate(28, (i) => _day(i, hrv: 50, rhr: 54)));
    final adverse = _score(_day(28, hrv: 50, rhr: 54), _sleep(75));
    expect(habitual.score, closeTo(65, 1e-8));
    expect(adverse.score, lessThan(habitual.score!));
  });
}

ScoreResult _score(DailyWearableData today, ScoreResult sleep,
        {HistoricalDailyData? history}) =>
    calculateRecoveryScoreResult(
        _profile, today, history ?? List.generate(28, _day), sleep);

DailyWearableData _day(int offset, {double? hrv = 70, double rhr = 50}) =>
    DailyWearableData(
      date: DateTime.utc(2026, 8, 1)
          .add(Duration(days: offset))
          .toIso8601String()
          .split('T')
          .first,
      hrvRmssdMs: hrv,
      hrvMetric: 'rmssd',
      restingHeartRateBpm: rhr,
      skinTemperatureCelsius: 36.5,
      temperatureMetric: 'wrist_temperature_celsius',
      respiratoryRate: 14,
      spo2Percent: 98,
    );

ScoreResult _sleep(double value, {double confidence = 1}) => ScoreResult(
    score: value,
    status: confidence < 1 ? ScoreStatus.partialData : ScoreStatus.ok,
    confidence: confidence,
    components: const {},
    warnings: const []);
