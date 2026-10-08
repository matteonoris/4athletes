import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/health_consent_screen.dart';
import 'package:flutter_mobile/services/health_consent_service.dart';
import 'package:flutter_mobile/widgets/health_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository implements HealthConsentRepository {
  HealthConsentDecision? choice;
  bool failSave = false;
  @override
  Future<HealthConsentDecision?> latest(String owner) async => choice;
  @override
  Future<void> record(String owner, HealthConsentDecision decision) async {
    if (failSave) throw StateError('Unavailable');
    choice = decision;
  }
}

class _State extends AppState {
  _State(HealthConsentRepository repository)
      : super(healthConsentRepository: repository);
  @override
  String get userId => 'a';
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
  });
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
        'saved refusal bypasses the notice on subsequent access (${theme.brightness})',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _Repository();
      final state = _State(repository);
      await state.loadHealthConsent();
      Widget app(AppState current) => ChangeNotifierProvider<AppState>.value(
          value: current,
          child: MaterialApp(
              theme: theme,
              home: const HealthConsentGate(
                  child: Scaffold(body: Text('App disponibile')))));
      await tester.pumpWidget(app(state));
      expect(find.byType(HealthConsentScreen), findsOneWidget);
      final decline = find.text('Continua senza collegare i dati salute');
      await tester.scrollUntilVisible(decline, 250);
      await tester.tap(decline);
      await tester.pumpAndSettle();
      expect(repository.choice, HealthConsentDecision.declined);
      expect(find.text('App disponibile'), findsOneWidget);
      expect(state.canImportHealthData, isFalse);
      final restored = _State(repository);
      await restored.loadHealthConsent();
      await tester.pumpWidget(app(restored));
      await tester.pumpAndSettle();
      expect(find.byType(HealthConsentScreen), findsNothing);
      expect(find.text('App disponibile'), findsOneWidget);
    });
  }

  testWidgets('failed save keeps the gate and never opens the app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _Repository()..failSave = true;
    final state = _State(repository);
    await state.loadHealthConsent();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
            home: HealthConsentGate(child: Text('App disponibile')))));
    final decline = find.text('Continua senza collegare i dati salute');
    await tester.scrollUntilVisible(decline, 250);
    await tester.tap(decline);
    await tester.pumpAndSettle();
    expect(find.byType(HealthConsentScreen), findsOneWidget);
    expect(find.text('Non è stato possibile salvare la tua scelta. Riprova.'),
        findsOneWidget);
    expect(find.text('App disponibile'), findsNothing);
    expect(state.canImportHealthData, isFalse);
  });
}
