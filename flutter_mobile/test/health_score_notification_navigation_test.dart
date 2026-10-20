import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/main.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/health_consent_screen.dart';
import 'package:flutter_mobile/screens/home_screen.dart';
import 'package:flutter_mobile/services/daily_strain_persistence_service.dart';
import 'package:flutter_mobile/services/health_consent_service.dart';
import 'package:flutter_mobile/services/training_reminder_notification_service.dart';
import 'package:flutter_mobile/widgets/bottom_nav.dart';
import 'package:flutter_mobile/widgets/health_score_notice_host.dart';
import 'package:flutter_mobile/widgets/health_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final taps =
      TrainingReminderNotificationService.instance.healthScoreNotificationTap;

  setUpAll(() async {
    await (FontLoader('Lexend')
          ..addFont(rootBundle.load('assets/fonts/Lexend-Regular.ttf')))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://synthetic.invalid',
        anonKey: 'synthetic',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() => taps.value = null);
  tearDown(() => taps.value = null);

  Future<_NavigationState> openApp(WidgetTester tester, String theme) async {
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _NavigationState(theme);
    final today = localDateKey(DateTime.now());
    state.addLocalBodyLog(BodyMetricLog(
        id: 'sleep', date: today, type: 'sleep_score', value: 82));
    state.addLocalBodyLog(BodyMetricLog(
        id: 'recovery', date: today, type: 'recovery_score', value: 78));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state, child: const FourAthletesApp()));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
    return state;
  }

  for (final theme in ['light', 'dark']) {
    for (final payload in [
      'health_scores_sync',
      'health_scores_ready:${localDateKey(DateTime.now())}'
    ]) {
      testWidgets('$payload returns to today on Home in $theme',
          (tester) async {
        final state = await openApp(tester, theme);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        // Social signup replaces the initial app route with its own Home.
        navigator.pushReplacement(MaterialPageRoute<void>(
            builder: (_) => const HealthConsentGate(child: HomeScreen())));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.chevron_left).first);
        await tester.pumpAndSettle();
        expect(state.currentHealthDateKey,
            localDateKey(DateTime.now().subtract(const Duration(days: 1))));
        await tester.tap(find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Salute')));
        await tester.pumpAndSettle();
        expect(
            tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 2);

        navigator.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Dettaglio aperto'))));
        await tester.pumpAndSettle();
        expect(find.text('Dettaglio aperto'), findsOneWidget);

        taps.value = payload;
        await tester.pumpAndSettle();
        expect(find.text('Dettaglio aperto'), findsNothing);
        expect(
            tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 0);
        expect(find.text('Oggi'), findsOneWidget);
        expect(find.text('82'), findsOneWidget);
        expect(find.text('78'), findsOneWidget);
        expect(state.currentHealthDateKey, localDateKey(DateTime.now()));
        expect(navigator.canPop(), isFalse);

        taps.value = payload;
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(navigator.canPop(), isFalse);
        expect(taps.value, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a launch tap opens Home after the navigator is ready',
      (tester) async {
    taps.value = 'health_scores_ready:${localDateKey(DateTime.now())}';
    await openApp(tester, 'light');
    expect(taps.value, isNull);
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 0);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });

  testWidgets('a notification tap preserves the health consent gate',
      (tester) async {
    final state = await openApp(tester, 'light');
    state.healthConsent.decision = null;
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(HealthConsentScreen), findsOneWidget);
    taps.value = 'health_scores_sync';
    await tester.pumpAndSettle();
    expect(find.byType(HealthConsentScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('notification taps are discarded after logout or for a coach',
      (tester) async {
    final state = _NavigationState('light');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: const Scaffold(),
        builder: (context, child) => HealthScoreNoticeHost(
            state: state, onOpenScores: () => opened++, child: child!)));
    state.loggedIn = false;
    taps.value = 'health_scores_sync';
    await tester.pump();
    expect(opened, 0);
    expect(taps.value, isNull);
    state.loggedIn = true;
    state.testProfile.role = 'coach';
    taps.value = 'health_scores_ready:${localDateKey(DateTime.now())}';
    await tester.pump();
    expect(opened, 0);
    expect(taps.value, isNull);
  });
}

class _NavigationState extends AppState {
  _NavigationState(this.testTheme) {
    healthConsent.loaded = true;
    healthConsent.decision = HealthConsentDecision.declined;
  }

  final String testTheme;
  bool loggedIn = true;
  final testProfile = UserProfile(
      id: 'synthetic-athlete',
      firstName: 'Atleta',
      lastName: 'Demo',
      email: 'athlete@example.invalid',
      birthDate: '1995-01-15',
      role: 'athlete',
      weight: 70,
      height: 175,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: '',
      notificationsEnabled: true,
      connectedDevices: []);

  @override
  bool get isInitialized => true;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  String get userId => 'synthetic-athlete';
  @override
  UserProfile? get userProfile => testProfile;
  @override
  String get themeMode => testTheme;
}
