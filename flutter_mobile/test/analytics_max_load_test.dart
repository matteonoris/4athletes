import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/analytics_screen.dart';
import 'package:flutter_mobile/utils/max_load_analytics_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AnalyticsTestState extends AppState {
  final List<PRLog> _testPrLogs;

  _AnalyticsTestState(this._testPrLogs);

  @override
  List<PRLog> get prLogs => _testPrLogs;
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

  test('ordina prima gli esercizi con massimali aggiornati di recente', () {
    final ids = trackedMaxLoadExerciseIds([
      PRLog(
        id: '1',
        exerciseId: 'back_squat',
        date: '2026-07-10',
        weight: 120,
      ),
      PRLog(
        id: '2',
        exerciseId: 'front_squat',
        date: '2026-07-14',
        weight: 100,
      ),
    ]);

    expect(ids.first, 'front_squat');
    expect(ids, containsAll(defaultMaxLoadExerciseIds));
    expect(maxLoadExerciseName('front_squat'), 'Front Squat');
  });

  testWidgets('max load limita anteprima e ogni card apre lo storico',
      (tester) async {
    final logs = [
      PRLog(
          id: '1', exerciseId: 'front_squat', date: '2026-07-14', weight: 100),
      PRLog(id: '2', exerciseId: 'back_squat', date: '2026-07-13', weight: 120),
      PRLog(id: '3', exerciseId: 'deadlift', date: '2026-07-12', weight: 150),
      PRLog(id: '4', exerciseId: 'bp', date: '2026-07-11', weight: 90),
      PRLog(id: '5', exerciseId: 'clean_jerk', date: '2026-07-10', weight: 85),
      PRLog(id: '6', exerciseId: 'rdl', date: '2026-07-09', weight: 130),
    ];
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _AnalyticsTestState(logs),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('add_max_load_exercise')), findsOneWidget);
    expect(find.byKey(const ValueKey('view_all_max_loads')), findsOneWidget);
    expect(find.byKey(const ValueKey('max_load_front_squat')), findsOneWidget);
    expect(find.byKey(const ValueKey('max_load_clean_jerk')), findsNothing);

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view_all_max_loads')));
    await tester.pumpAndSettle();
    expect(find.text('Tutti i massimali'), findsOneWidget);
    expect(find.byKey(const ValueKey('all_max_load_rdl')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('all_max_load_rdl')));
    await tester.pumpAndSettle();
    expect(find.text('Romanian Deadlift (RDL)'), findsOneWidget);
    expect(find.text('Performance Trend'), findsOneWidget);
    expect(find.textContaining('History'), findsOneWidget);
  });

  testWidgets('aggiungi massimale usa qualsiasi esercizio del database',
      (tester) async {
    AppTheme.setThemeMode(
      AppTheme.darkMode,
      platformBrightness: Brightness.dark,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _AnalyticsTestState(const []),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('add_max_load_exercise')),
    );
    await tester.tap(find.byKey(const ValueKey('add_max_load_exercise')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('max_load_exercise_search')),
      'Front Squat',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('max_load_picker_front_squat')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Front Squat'), findsOneWidget);
    expect(find.text('Nuovo Record: Front Squat'), findsOneWidget);
  });
}
