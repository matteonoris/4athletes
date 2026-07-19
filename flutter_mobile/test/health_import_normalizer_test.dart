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

  test('mantiene un picco cardiaco breve ma valido', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(0, 140),
      sample(30, 142),
      sample(60, 144),
      sample(90, 220),
      sample(120, 145),
      sample(150, 146),
      sample(180, 148),
    ]);

    expect(
      cleaned.map((sample) => sample.bpm).toList(),
      [140, 142, 144, 220, 145, 146, 148],
    );

    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: cleaned,
      zones: zones,
    );
    expect(metrics.maxHeartRate, 220);
  });

  test('mantiene campioni distinti con lo stesso timestamp', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(0, 140.25),
      sample(0, 141.75),
    ]);

    expect(cleaned, hasLength(2));
    expect(
      cleaned.map((sample) => sample.bpm).toList(),
      [140.25, 141.75],
    );
  });

  test('serializza i bpm frazionari senza arrotondarli', () {
    final serialized = HealthImportNormalizer.serializeHeartRateSamples([
      sample(0, 109.25),
    ]);

    expect(serialized.single['bpm'], 109.25);
  });

  test('ordina i campioni per timestamp senza alterarne i valori', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(30, 143.5),
      sample(0, 140.5),
      sample(20, 142.5),
      sample(10, 141.5),
    ]);

    expect(
      cleaned.map((sample) => sample.time).toList(),
      [
        base,
        base.add(const Duration(seconds: 10)),
        base.add(const Duration(seconds: 20)),
        base.add(const Duration(seconds: 30)),
      ],
    );
    expect(
      cleaned.map((sample) => sample.bpm).toList(),
      [140.5, 141.5, 142.5, 143.5],
    );
  });

  test('scarta solo bpm non finiti o fuori dal range Health Connect', () {
    final cleaned = HealthImportNormalizer.cleanHeartRateSamples([
      sample(0, double.nan),
      sample(1, double.infinity),
      sample(2, double.negativeInfinity),
      sample(3, -1),
      sample(4, 0),
      sample(5, 0.9),
      sample(6, 1),
      sample(7, 34.5),
      sample(8, 235.5),
      sample(9, 300),
      sample(10, 300.1),
    ]);

    expect(
      cleaned.map((sample) => sample.bpm).toList(),
      [1, 34.5, 235.5, 300],
    );
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

  test('suddivide un segmento nelle zone cardiache attraversate', () {
    final metrics = HealthImportNormalizer.calculateHeartRateMetrics(
      samples: [
        sample(0, 130),
        sample(10, 190),
      ],
      zones: zones,
    );

    expect(metrics.averageHeartRate, 160);
    expect(
        HealthImportNormalizer.roundedZoneSeconds(
          metrics.zoneSeconds,
          targetSeconds: metrics.coverageSeconds,
        ),
        [
          0,
          0,
          2,
          3,
          3,
          2,
        ]);
  });

  test('non manda in Z5 i bpm nel limite inclusivo della Z4', () {
    const inclusiveZones = [
      {'min': 100, 'max': 119},
      {'min': 120, 'max': 139},
      {'min': 140, 'max': 159},
      {'min': 160, 'max': 175},
      {'min': 176, 'max': 200},
    ];

    expect(
      HealthImportNormalizer.zoneIndexForBpm(175, inclusiveZones),
      4,
    );
    expect(
      HealthImportNormalizer.zoneIndexForBpm(175.9, inclusiveZones),
      4,
    );
    expect(
      HealthImportNormalizer.zoneIndexForBpm(176, inclusiveZones),
      5,
    );
  });

  test('usa le soglie personalizzate del profilo come fonte di verita', () {
    const custom = [
      {'min': 95, 'max': 114},
      {'min': 115, 'max': 134},
      {'min': 135, 'max': 154},
      {'min': 155, 'max': 174},
      {'min': 175, 'max': 300},
    ];

    final resolved = HealthImportNormalizer.resolveHeartRateZones(
      mode: 'custom',
      customZones: custom,
      maxHeartRate: 200,
    );

    expect(resolved, custom);
    expect(HealthImportNormalizer.zoneIndexForBpm(174, resolved), 4);
    expect(HealthImportNormalizer.zoneIndexForBpm(175, resolved), 5);
  });

  test('arrotonda le zone mantenendo la durata coperta totale', () {
    expect(
      HealthImportNormalizer.roundedZoneSeconds(
        const [0, 0, 1.6, 3.3, 3.4, 1.7],
        targetSeconds: 10,
      ).fold<int>(0, (sum, value) => sum + value),
      10,
    );
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
      15,
      15,
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
      30,
      30,
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
