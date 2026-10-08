import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/health_consent_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    Future<void> open(
      WidgetTester tester, {
      required Future<void> Function() accept,
      required Future<void> Function() decline,
      String providerName = 'Health Connect',
      bool existingUser = true,
      VoidCallback? openPrivacy,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: HealthConsentScreen(
          providerName: providerName,
          existingUser: existingUser,
          onAccept: accept,
          onDecline: decline,
          onOpenPrivacy: openPrivacy,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> click(WidgetTester tester, String text) async {
      final target = find.text(text);
      await tester.scrollUntilVisible(target, 250);
      await tester.tap(target, warnIfMissed: true);
      await tester.pump();
    }

    testWidgets('notice covers sleep and shared storage ($brightness)',
        (tester) async {
      var accepted = 0;
      var declined = 0;
      await open(tester,
          accept: () async => accepted++, decline: () async => declined++);
      expect(find.text('UNA SCELTA PER IL TUO ACCOUNT'), findsOneWidget);
      expect(find.text('Sonno e recupero'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Chi può consultarli'), 250);
      expect(find.textContaining('Supabase'), findsOneWidget);
      expect(find.textContaining('Matteo Noris'), findsOneWidget);
      await click(tester, 'Continua senza collegare i dati salute');
      await tester.pumpAndSettle();
      expect(accepted, 0);
      expect(declined, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits for saving and prevents duplicate accept ($brightness)',
        (tester) async {
      var accepted = 0;
      var declined = 0;
      final pending = Completer<void>();
      await open(tester,
          accept: () {
            accepted++;
            return pending.future;
          },
          decline: () async => declined++);
      await click(tester, 'Acconsento e collega Health Connect');
      expect(accepted, 1);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      expect(declined, 0);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('save error stays visible and allows retry ($brightness)',
        (tester) async {
      var attempts = 0;
      await open(tester, accept: () async {
        attempts++;
        throw StateError('storage unavailable');
      }, decline: () async {});
      await click(tester, 'Acconsento e collega Health Connect');
      await tester.pumpAndSettle();
      expect(find.text('Non è stato possibile salvare la tua scelta. Riprova.'),
          findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      await click(tester, 'Acconsento e collega Health Connect');
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('signup and Apple disclosure with privacy link ($brightness)',
        (tester) async {
      var privacyOpened = false;
      await open(tester,
          accept: () async {},
          decline: () async {},
          providerName: 'Apple Health',
          existingUser: false,
          openPrivacy: () => privacyOpened = true);
      expect(find.text('PRIMA DI COLLEGARE I TUOI DATI'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ciclo mestruale'), 250);
      expect(find.text('Ciclo mestruale'), findsOneWidget);
      await click(tester, 'Leggi l’informativa privacy');
      await tester.pumpAndSettle();
      expect(privacyOpened, true);
      expect(tester.takeException(), isNull);
    });
  }
}
