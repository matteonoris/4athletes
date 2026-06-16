import 'package:flutter_mobile/services/health_import_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 6, 1, 16, 42);
  HeartRateSample sample(int seconds, double bpm) {
    return HeartRateSample(base.add(Duration(seconds: seconds)), bpm);
  }

  const zones = [
    {'min': 100, 'max': 120},
    {'min': 120, 'max': 140},
    {'min': 140, 'max': 160},
    {'min': 160, 'max': 180},
    {'min': 180, 'max': 200},
  ];

  test('ignora uno spike cardiaco alto e isolato', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(0, 140),
      sample(30, 142),
      sample(60, 144),
      sample(90, 220),
      sample(120, 145),
      sample(150, 146),
      sample(180, 148),
    ]);

    expect(cleaned.map((sample) => sample.bpm), isNot(contains(220)));

    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: cleaned,
      zones: zones,
    );
    expect(metrics.maxHeartRate, 148);
    expect(metrics.averageHeartRate, lessThan(150));
  });

  test('mantiene una frequenza alta quando e sostenuta', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(0, 140),
      sample(30, 145),
      sample(60, 180),
      sample(90, 184),
      sample(120, 186),
      sample(150, 183),
      sample(180, 150),
    ]);

    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: cleaned,
      zones: zones,
    );

    expect(metrics.maxHeartRate, 186);
    expect(cleaned.map((sample) => sample.bpm), containsAll([180, 184, 186]));
  });

  test('calcola zone Z0-Z5 sulla durata coperta dai battiti', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(0, 90),
        sample(60, 90),
        sample(400, 110),
        sample(460, 110),
        sample(800, 130),
        sample(860, 130),
        sample(1200, 150),
        sample(1260, 150),
        sample(1600, 170),
        sample(1660, 170),
        sample(2000, 190),
        sample(2060, 190),
      ],
      zones: zones,
    );

    expect(metrics.coverageSeconds, 360);
    expect(metrics.zoneSeconds.map((seconds) => seconds.round()).toList(), [
      60,
      60,
      60,
      60,
      60,
      60,
    ]);
    expect(
      metrics.zoneSeconds.fold<double>(0, (sum, seconds) => sum + seconds),
      metrics.coverageSeconds,
    );
  });

  test('assegna la zona al campione misurato, non alla media del segmento', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(0, 130),
        sample(10, 190),
      ],
      zones: zones,
    );

    expect(metrics.averageHeartRate, 160);
    expect(metrics.zoneSeconds.map((seconds) => seconds.round()).toList(), [
      0,
      0,
      10,
      0,
      0,
      0,
    ]);
  });

  test('include piccoli bordi start/end dell allenamento', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(10, 130),
        sample(20, 150),
      ],
      zones: zones,
      workoutStart: base,
      workoutEnd: base.add(const Duration(seconds: 30)),
    );

    expect(metrics.coverageSeconds, 30);
    expect(metrics.zoneSeconds.map((seconds) => seconds.round()).toList(), [
      0,
      0,
      20,
      10,
      0,
      0,
    ]);
  });

  test('non riempie bordi grandi senza campioni cardiaci', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(120, 130),
        sample(180, 150),
      ],
      zones: zones,
      workoutStart: base,
      workoutEnd: base.add(const Duration(seconds: 360)),
    );

    expect(metrics.coverageSeconds, 60);
    expect(metrics.zoneSeconds.map((seconds) => seconds.round()).toList(), [
      0,
      0,
      60,
      0,
      0,
      0,
    ]);
  });

  test('richiede copertura minima per mostrare i battiti', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(0, 130),
        sample(30, 132),
        sample(60, 134),
        sample(90, 136),
        sample(120, 138),
      ],
      zones: zones,
    );

    expect(HealthImportNormalizer.isReliableHeartRate(metrics, 240), isTrue);
    expect(HealthImportNormalizer.isReliableHeartRate(metrics, 300), isFalse);
  });

  test('considera continui i battiti campionati fino a cinque minuti', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(0, 130),
        sample(300, 132),
        sample(600, 134),
      ],
      zones: zones,
    );

    expect(metrics.coverageSeconds, 600);
  });

  test('mantiene la moving duration separata dalla durata ufficiale', () {
    final movingDuration = HealthImportNormalizer.deriveMovingDurationSeconds(
      elapsedSeconds: 3600,
      distanceCoverageSeconds: 1800,
      heartRateCoverageSeconds: 1800,
      hasDistance: true,
    );

    expect(movingDuration, 1800);
  });
}
