import 'package:flutter/material.dart';
import 'package:flutter_mobile/screens/daily_readiness_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('personal sleep stages render in ${brightness.name} mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const DailyReadinessDetailsScreen(
          title: 'Sleep',
          score: 76,
          dailyMetrics: {
            'deepSleep': 70,
            'remSleep': 90,
            'lightSleep': 300,
            'deepSleepBaselineMinutes': 100,
            'remSleepBaselineMinutes': 110,
            'lightSleepBaselineMinutes': 290,
            'sleepStageBaselineNights': 14,
            'sleepStagePenalty': 3,
            'sleepScoreConfidence': 0.9,
          },
          historicalMetrics: {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fasi confrontate con le tue ultime 14'),
          findsOneWidget);
      expect(find.text('Mediana personale: 1h 40m'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sonno Leggero'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Mediana personale: 4h 50m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'recovery metadata and confidence render in ${brightness.name} mode',
      (tester) async {
        final isDark = brightness == Brightness.dark;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: DailyReadinessDetailsScreen(
              title: 'Recovery',
              score: 72,
              dailyMetrics: {
                'rhr': 48,
                'hrv': 68,
                'temp': isDark ? 36.4 : 0.3,
                'tempIsDelta': isDark ? 0 : 1,
                'hrvIsSdnn': isDark ? 1 : 0,
                'resp': 14,
                'spo2': 98,
                'recoveryScoreConfidence': 0.8,
              },
              historicalMetrics: const {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Affidabilità dati 80%'), findsOneWidget);
        expect(
          find.text('HRV'),
          findsOneWidget,
        );
        expect(
          find.text(
            isDark
                ? 'Temperatura notturna al polso (°C)'
                : 'Deviazione temperatura cutanea (°C)',
          ),
          findsOneWidget,
        );
      },
    );
  }
}
