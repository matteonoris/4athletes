import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/activity_details_screen.dart';

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

  Future<void> pumpDetails(
    WidgetTester tester,
    TrainingSession session, {
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    AppTheme.setThemeMode(
      themeMode == ThemeMode.dark ? AppTheme.darkMode : AppTheme.lightMode,
      platformBrightness:
          themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: ActivityDetailsScreen(session: session, prLogs: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('il dettaglio tennis mostra un riepilogo pulito senza metadati',
      (tester) async {
    final draft = WorkoutDraft(
      id: 'workout_very_long_internal_identifier',
      createdByUserId: 'user_very_long_internal_identifier',
      creatorRole: 'athlete',
      athleteOwnerId: 'athlete_very_long_internal_identifier',
      title: 'Tennis',
      date: DateTime(2026, 7, 15),
      plannedStartTime: '12:00',
      plannedEndTime: '12:46',
      actualStartTime: '12:00',
      actualEndTime: '13:00',
      actualDurationMinutes: 60,
      location: 'Lallio',
      activityId: 'tennis',
      activityName: 'Tennis',
      activityCategory: ActivityCategory.sport,
      editorKind: 'universal',
      status: ActivityStatus.completed,
      phases: const [
        WorkoutPhaseDraft(
          type: TrainingPhase.main,
          blocks: [
            WorkoutBlockDraft(
              id: 'block_internal_identifier',
              kind: WorkoutBlockKind.sport,
              title: 'Partita',
              order: 0,
              fields: {'durationMinutes': 60},
            ),
          ],
        ),
      ],
      updatedAt: DateTime(2026, 7, 15, 13),
    );

    await pumpDetails(tester, draft.toTrainingSession());

    expect(find.text('Tennis'), findsOneWidget);
    expect(find.text('Allenamento'), findsOneWidget);
    expect(find.text('Lallio'), findsOneWidget);
    expect(find.text('Partita'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('Schema Version'), findsNothing);
    expect(find.text('Workout Draft'), findsNothing);
    expect(find.text('workout_very_long_internal_identifier'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lo sci alpino dell atleta usa sempre il dettaglio dedicato',
      (tester) async {
    final session = TrainingSession(
      id: 'ski-athlete-session',
      sportId: 'alpine_skiing',
      date: '2026-07-15',
      startTime: '09:00',
      endTime: '11:00',
      duration: '120',
      effort: 7,
      details: const {'notes': 'Allenamento personale'},
    );

    await pumpDetails(tester, session, themeMode: ThemeMode.light);

    expect(find.text('Riepilogo'), findsOneWidget);
    expect(find.text('Creato da te'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dati personali'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dati personali'), findsOneWidget);
    expect(find.text('Workout Draft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'un weightlifting legacy apre sempre il nuovo editor in chiaro e scuro',
      (tester) async {
    final session = TrainingSession(
      id: 'legacy-weightlifting',
      sportId: 'weightlifting',
      date: '2026-07-14',
      startTime: '09:40',
      endTime: '10:20',
      duration: '40',
      effort: 5,
      details: const {
        'location': 'Palestra',
        'notes': 'Tecnica prima del carico',
        'exercises': [
          {
            'id': 'snatch_legacy',
            'name': 'Snatch tecnico',
            'sets': [
              {'kg': 45, 'reps': 3},
              {'kg': 50, 'reps': 2},
            ],
          },
        ],
      },
    );

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      SharedPreferences.setMockInitialValues({});
      await pumpDetails(tester, session, themeMode: themeMode);

      await tester.tap(find.byTooltip('Modifica allenamento'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica allenamento'), findsOneWidget);
      expect(find.text('Weightlifting'), findsWidgets);
      expect(find.text('Snatch tecnico'), findsOneWidget);
      final titleField = tester.widget<TextField>(
        find.byKey(const ValueKey('workout_title_field')),
      );
      expect(titleField.controller?.text, 'Weightlifting');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });
}
