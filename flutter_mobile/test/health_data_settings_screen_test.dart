import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/health_data_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    Future<void> open(
      WidgetTester tester, {
      required bool granted,
      required Future<void> Function() revoke,
      required Future<bool> Function() enable,
      required VoidCallback deletion,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: HealthDataSettingsScreen(
          providerName: 'Health Connect',
          consentGranted: granted,
          onRevoke: revoke,
          onEnable: enable,
          onRequestDeletion: deletion,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('revocation and deletion stay separate ($brightness)',
        (tester) async {
      final pending = Completer<void>();
      var deletionCalled = false;
      await open(tester,
          granted: true,
          revoke: () => pending.future,
          enable: () async => false,
          deletion: () => deletionCalled = true);
      await tester.tap(find.text('Revoca il consenso'));
      await tester.pump();
      expect(find.text('Consenso non attivo'), findsOneWidget);
      expect(deletionCalled, false);
      pending.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Richiedi eliminazione dati salute'));
      await tester.pumpAndSettle();
      expect(deletionCalled, true);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'failed revoke retries without silently re-enabling ($brightness)',
        (tester) async {
      var revokeCalls = 0;
      var enableCalls = 0;
      await open(tester, granted: true, revoke: () async {
        revokeCalls++;
        if (revokeCalls == 1) throw StateError('offline');
      }, enable: () async {
        enableCalls++;
        return true;
      }, deletion: () {});
      await tester.tap(find.text('Revoca il consenso'));
      await tester.pumpAndSettle();
      expect(find.text('Consenso non attivo'), findsOneWidget);
      expect(find.text('Riprova la revoca'), findsOneWidget);
      await tester.tap(find.text('Riprova la revoca'));
      await tester.pumpAndSettle();
      expect(revokeCalls, 2);
      expect(enableCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('declining re-enable keeps imports off ($brightness)',
        (tester) async {
      await open(tester,
          granted: false,
          revoke: () async {},
          enable: () async => false,
          deletion: () {});
      await tester.tap(find.text('Leggi e attiva il consenso'));
      await tester.pumpAndSettle();
      expect(find.text('Consenso non attivo'), findsOneWidget);
      expect(find.text('Revoca il consenso'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
