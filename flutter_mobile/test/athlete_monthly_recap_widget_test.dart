import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/analytics_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecapTestState extends AppState {
  final List<TrainingSession> testSessions;
  final List<CalendarEvent> testEvents;
  final UserProfile testProfile;

  _RecapTestState({
    required this.testSessions,
  })  : testEvents = const [],
        testProfile = _profile();

  @override
  List<TrainingSession> get sessions => testSessions;

  @override
  List<CalendarEvent> get coachEvents => testEvents;

  @override
  UserProfile? get profile => testProfile;

  @override
  UserProfile? get userProfile => testProfile;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it');
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbmUifQ.placeholder',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
    }
  });

  testWidgets('card apre dettaglio, confronto e categorie in tema chiaro',
      (tester) async {
    final now = DateTime.now();
    final state = _RecapTestState(
      testSessions: [
        _session(
          id: 'ski',
          date: now,
          sportId: 'alpine_skiing',
          duration: '120',
          details: {
            'specialties': ['SL', 'GS'],
            'tracks': [
              {'specialty': 'SL', 'laps': 2, 'gates': 20},
              {'specialty': 'GS', 'laps': 2, 'gates': 25},
            ],
          },
        ),
        _session(
          id: 'strength',
          date: now,
          sportId: 'dryland_strength',
          duration: '60',
          details: {
            'status': ActivityStatus.completed,
            'activityDomain': 'dryland',
            'activityCategory': ActivityCategory.strength,
          },
        ),
        _session(
          id: 'previous',
          date: DateTime(now.year, now.month - 1, 1),
          sportId: 'running',
          duration: '90',
        ),
      ],
    );

    await _pumpAnalytics(tester, state, ThemeMode.light);

    expect(
      find.byKey(const ValueKey('athlete_monthly_recap_card')),
      findsOneWidget,
    );
    final total = tester.widget<Text>(
      find.byKey(const ValueKey('monthly_recap_total_duration')),
    );
    expect(total.data, '3h');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('open_monthly_recap_details')));
    await tester.pumpAndSettle();

    expect(find.text('Recap allenamenti'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('athlete_monthly_recap_details')),
      findsOneWidget,
    );
    expect(find.text('Confronto del volume'), findsOneWidget);

    final previousMonth =
        find.byKey(const ValueKey('monthly_recap_previous_month'));
    expect(tester.widget<IconButton>(previousMonth).onPressed, isNotNull);
    await tester.tap(previousMonth);
    await tester.pumpAndSettle();
    final nextMonth = find.byKey(const ValueKey('monthly_recap_next_month'));
    expect(tester.widget<IconButton>(nextMonth).onPressed, isNotNull);
    await tester.tap(nextMonth);
    await tester.pumpAndSettle();

    final skiTile = find.byKey(const ValueKey('monthly_recap_bucket_ski'));
    await tester.ensureVisible(skiTile);
    await tester.tap(skiTile);
    await tester.pumpAndSettle();
    expect(find.text('SL'), findsOneWidget);
    expect(find.text('GS'), findsOneWidget);

    final prepTile =
        find.byKey(const ValueKey('monthly_recap_bucket_preparation'));
    await tester.scrollUntilVisible(
      prepTile,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(prepTile);
    await tester.pumpAndSettle();
    expect(find.text('Forza'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stato vuoto e layout non generano overflow in tema scuro',
      (tester) async {
    final state = _RecapTestState(testSessions: const []);
    await _pumpAnalytics(tester, state, ThemeMode.dark);

    final total = tester.widget<Text>(
      find.byKey(const ValueKey('monthly_recap_total_duration')),
    );
    expect(total.data, '0m');

    await tester.tap(find.byKey(const ValueKey('open_monthly_recap_details')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('monthly_recap_empty_state')),
    );
    expect(
      find.byKey(const ValueKey('monthly_recap_empty_state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAnalytics(
  WidgetTester tester,
  AppState state,
  ThemeMode mode,
) async {
  AppTheme.setThemeMode(
    mode == ThemeMode.dark ? AppTheme.darkMode : AppTheme.lightMode,
    platformBrightness:
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
  );
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: const AnalyticsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TrainingSession _session({
  required String id,
  required DateTime date,
  required String sportId,
  required String duration,
  Map<String, dynamic>? details,
}) {
  return TrainingSession(
    id: id,
    sportId: sportId,
    date:
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    startTime: '09:00',
    endTime: '10:00',
    duration: duration,
    effort: 5,
    details: details,
  );
}

UserProfile _profile() => UserProfile(
      id: 'athlete-1',
      firstName: 'Ada',
      lastName: 'Rossi',
      email: 'ada@example.com',
      birthDate: '2000-01-01',
      role: 'athlete',
      weight: 60,
      height: 170,
      maxHr: 195,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl: '',
      notificationsEnabled: true,
      connectedDevices: const [],
    );
