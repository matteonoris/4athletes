import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/activity_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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

  TrainingSession structuredSession() => TrainingSession(
        id: 'session_1',
        sportId: 'dryland_strength',
        date: '2026-07-14',
        startTime: '15:00',
        endTime: '16:00',
        duration: '60',
        effort: 8,
        eventId: 'event_1',
        details: const {
          'schemaVersion': 3,
          'activityDomain': 'dryland',
          'activityCategory': ActivityCategory.strength,
          'source': ActivitySource.coach,
          'from_calendar': true,
          'createdByCoach': true,
          'title': 'Forza parte alta',
          'blocks': [
            {
              'id': 'main_1',
              'type': TrainingBlockType.strength,
              'name': 'Lavoro principale',
              'metrics': {'phase': TrainingPhase.main},
              'exercises': [
                {
                  'exerciseId': 'back_squat',
                  'name': 'Back Squat',
                  'sets': [
                    {'setNumber': 1, 'kg': 100, 'reps': 5, 'rpe': 8},
                    {'setNumber': 2, 'kg': 105, 'reps': 4, 'rpe': 9},
                  ],
                },
              ],
            },
          ],
        },
      );

  Future<void> pumpSummary(
    WidgetTester tester, {
    required bool readOnly,
  }) async {
    AppTheme.setThemeMode(
      AppTheme.darkMode,
      platformBrightness: Brightness.dark,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: ActivityDetailsScreen(
            session: structuredSession(),
            readOnly: readOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('atleta vede il riepilogo strutturato dopo il salvataggio',
      (tester) async {
    await pumpSummary(tester, readOnly: false);

    expect(find.text('Riepilogo allenamento'), findsOneWidget);
    expect(find.text('Forza parte alta'), findsOneWidget);
    expect(find.byTooltip('Modifica allenamento'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Back Squat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Back Squat'), findsOneWidget);
  });

  testWidgets('report coach mostra lo stesso riepilogo in sola lettura',
      (tester) async {
    await pumpSummary(tester, readOnly: true);

    expect(find.text('Riepilogo allenamento'), findsOneWidget);
    expect(find.byTooltip('Modifica allenamento'), findsNothing);
    expect(find.byTooltip('Elimina allenamento'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Back Squat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Back Squat'), findsOneWidget);
  });
}
