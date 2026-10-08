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

class _EditableSessionsState extends AppState {
  final List<TrainingSession> recorded;
  final bool failSave;
  int saves = 0;

  _EditableSessionsState(TrainingSession session, {this.failSave = false})
      : recorded = [session];

  @override
  List<TrainingSession> get sessions => recorded;

  @override
  Future<void> addSession(
    TrainingSession session, {
    bool fromHealthSync = false,
    bool rethrowErrors = false,
    bool recalculateStrain = true,
    bool notify = true,
  }) async {
    saves++;
    if (failSave) throw StateError('Offline');
    recorded[0] = session;
    if (notify) notifyListeners();
  }
}

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
    AppState? appState,
    bool readOnly = false,
    String? sportName,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    AppTheme.setThemeMode(
      themeMode == ThemeMode.dark ? AppTheme.darkMode : AppTheme.lightMode,
      platformBrightness:
          themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => appState ?? AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: ActivityDetailsScreen(
              session: session,
              prLogs: const [],
              readOnly: readOnly,
              sportName: sportName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TrainingSession importedPreparation() => TrainingSession(
        id: 'imported-preparation',
        sportId: 'athletic_prep',
        date: '2026-10-05',
        startTime: '10:00',
        endTime: '11:00',
        duration: '60',
        effort: 5,
        details: const {
          'source': 'health_sync',
          'external_id': 'watch-workout',
          'rpe': 5,
          'source_device_id': 'internal-device-id',
          'unrecognized_provider_metadata': 'internal-value',
        },
      );

  testWidgets('tipologia importata modificabile in tema chiaro e scuro',
      (tester) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final session = importedPreparation();
      final state = _EditableSessionsState(session);
      await pumpDetails(tester, session,
          appState: state,
          themeMode: themeMode,
          sportName: 'Preparazione atletica');
      expect(find.text('Dettagli Tecnici'), findsNothing);
      expect(find.text('internal-device-id'), findsNothing);
      expect(find.text('internal-value'), findsNothing);
      await tester.tap(find.byTooltip('Modifica tipologia'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('workout_type_dryland_speed_agility')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_workout_type')));
      await tester.pumpAndSettle();
      expect(state.saves, 1);
      expect(state.recorded.single.sportId, 'dryland_speed_agility');
      expect(state.recorded.single.details?['external_id'], 'watch-workout');
      expect(find.text('Velocità e agilità'), findsWidgets);
      expect(find.text('Preparazione atletica'), findsNothing);
      expect(find.text('Tipologia aggiornata.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('annullare e fallire il salvataggio conservano la tipologia',
      (tester) async {
    final session = importedPreparation();
    final state = _EditableSessionsState(session, failSave: true);
    await pumpDetails(tester, session, appState: state);
    await tester.tap(find.byTooltip('Modifica tipologia'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('workout_type_dryland_speed_agility')));
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(state.saves, 0);
    expect(state.recorded.single.sportId, 'athletic_prep');
    await tester.tap(find.byTooltip('Modifica tipologia'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('workout_type_dryland_speed_agility')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_workout_type')));
    await tester.pumpAndSettle();
    expect(state.saves, 1);
    expect(state.recorded.single.sportId, 'athletic_prep');
    expect(find.text('Impossibile salvare la tipologia. Riprova.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ricerca tipologia e tastiera funzionano su schermo compatto',
      (tester) async {
    final session = importedPreparation();
    await pumpDetails(tester, session);
    await tester.tap(find.byTooltip('Modifica tipologia'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(
        find.byKey(const ValueKey('workout_type_search')), 'velocità');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workout_type_dryland_speed_agility')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('workout_type_dryland_strength')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('il dettaglio in sola lettura non consente di cambiare tipologia',
      (tester) async {
    await pumpDetails(tester, importedPreparation(), readOnly: true);
    expect(find.text('Tipologia'), findsOneWidget);
    expect(find.byTooltip('Modifica tipologia'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('workout_type_field')));
    await tester.pumpAndSettle();
    expect(find.text('Tipologia allenamento'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

    expect(find.text('Tennis'), findsNWidgets(2));
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
      'il dettaglio di una corsa importata accetta mappe native non tipizzate',
      (tester) async {
    final session = TrainingSession(
      id: 'imported-running-session',
      sportId: 'running',
      date: '2026-08-20',
      startTime: '11:30',
      endTime: '12:20',
      duration: '50',
      effort: 5,
      details: <String, dynamic>{
        'source': 'health_sync',
        'distance': '10 km',
        'laps': <Object?>[
          <Object?, Object?>{
            'distance': '1 km',
            'metrics': <Object?, Object?>{
              'pace': '5:00 /km',
            },
          },
        ],
      },
    );

    await pumpDetails(tester, session);

    expect(find.text('Dettagli Tecnici'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Giri e intervalli'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Giri e intervalli'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
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
