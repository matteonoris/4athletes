import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/workout_flow_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AppStateWithPr extends AppState {
  final List<PRLog> _testPrLogs;

  _AppStateWithPr(this._testPrLogs);

  @override
  List<PRLog> get prLogs => _testPrLogs;
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

  testWidgets('creazione mostra dati struttura e contenuto in una schermata',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nuovo allenamento'), findsOneWidget);
    expect(find.textContaining('Passaggio'), findsNothing);
    expect(find.byKey(const ValueKey('workout_single_page')), findsOneWidget);
    expect(find.byKey(const ValueKey('workout_title_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('workout_end_time')), findsOneWidget);
    expect(find.byKey(const ValueKey('workout_duration_field')), findsNothing);
    expect(find.text('Quanto vuoi dettagliare la sessione?'), findsOneWidget);
    expect(find.text('Costruisci le fasi'), findsOneWidget);
    expect(find.byKey(const ValueKey('session_rpe_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('session_rpe_slider')), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_workout_button')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('next_workout_step_button')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('structure_phased')));
    await tester.tap(
      find.byKey(const ValueKey('structure_phased')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riscaldamento'), findsOneWidget);
    expect(find.text('Lavoro principale'), findsOneWidget);
    expect(find.text('Defaticamento'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_block_main')), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    await tester.tap(switches.first);
    await tester.pump();
    expect(find.byKey(const ValueKey('add_block_warmup')), findsOneWidget);
  });

  testWidgets('forza apre il catalogo e non il menu generico dei blocchi',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('add_block_main')));
    await tester.tap(find.byKey(const ValueKey('add_block_main')));
    await tester.pumpAndSettle();

    expect(find.text('Seleziona esercizio'), findsOneWidget);
    expect(
      find.text(
          'Il nome proviene dal catalogo e viene salvato con un ID stabile.'),
      findsOneWidget,
    );
    expect(find.text('Esercizio con serie'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Back Squat').last);
    await tester.pumpAndSettle();
    expect(find.text('KG'), findsNWidgets(2));
    expect(find.text('RIPETIZIONI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serie per esercizio leggibili in tema chiaro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
          ),
        ),
      ),
    );
    await tester.pump();

    final exerciseCard = find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey &&
          widget.key.toString().contains('workout_block_'),
    );
    await tester.ensureVisible(exerciseCard.first);
    await tester.tap(exerciseCard.first);
    await tester.pumpAndSettle();

    expect(find.text('KG'), findsNWidgets(2));
    expect(find.text('RIPETIZIONI'), findsOneWidget);
    expect(find.text('Aggiungi serie'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_block_button')), findsOneWidget);
  });

  testWidgets('coach usa lo stesso flusso e seleziona gli atleti del team',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
            coachTeam: Team(
              id: 'team_1',
              name: 'Sci Club',
              members: 2,
              category: 'U18',
              image: '',
              inviteCode: 'ABC123',
            ),
            initialCoachParticipants: const [
              WorkoutParticipant(
                athleteId: 'athlete_1',
                name: 'Mario Rossi',
              ),
              WorkoutParticipant(
                athleteId: 'athlete_2',
                name: 'Giulia Bianchi',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
        find.byKey(const ValueKey('coach_participants_card')), findsOneWidget);
    expect(find.text('Sci Club'), findsOneWidget);
    expect(find.text('2 atleti selezionati'), findsOneWidget);
    expect(find.text('Pianificato'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Giulia Bianchi'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('coach_participant_athlete_2')),
    );
    await tester.pump();
    expect(find.text('1 atleta selezionato'), findsOneWidget);
  });

  testWidgets('tabella serie distingue numero e ripetizioni e modifica al tap',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SERIE'), findsOneWidget);
    expect(find.text('KG'), findsOneWidget);
    expect(find.text('REP'), findsOneWidget);
    expect(find.text('DETTAGLI'), findsOneWidget);

    final firstSet = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('workout_set_') &&
          (widget.key! as ValueKey<String>).value.endsWith('_0'),
    );
    await tester.ensureVisible(firstSet);
    await tester.tap(firstSet);
    await tester.pumpAndSettle();

    expect(find.textContaining('Serie 1'), findsOneWidget);
    final repsField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey &&
          widget.key.toString().contains('_0_single_reps'),
    );
    final kgField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey &&
          widget.key.toString().contains('_0_single_kg'),
    );
    await tester.enterText(kgField, '');
    await tester.enterText(repsField, '2');
    await tester.tap(find.byKey(const ValueKey('save_single_set_button')));
    await tester.pumpAndSettle();

    final updatedFirstSet = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('workout_set_') &&
          (widget.key! as ValueKey<String>).value.endsWith('_0'),
    );
    expect(
      find.descendant(of: updatedFirstSet, matching: find.text('—')),
      findsWidgets,
    );
    expect(
      find.descendant(of: updatedFirstSet, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('peso serie mostra percentuale dell ultimo massimale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.darkMode,
      platformBrightness: Brightness.dark,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _AppStateWithPr([
          PRLog(
            id: 'pr_1',
            exerciseId: 'back_squat',
            date: '2026-07-14',
            weight: 120,
          ),
        ]),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('dryland_strength'),
          ),
        ),
      ),
    );
    await tester.pump();

    final exerciseCard = find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey &&
          widget.key.toString().contains('workout_block_'),
    );
    await tester.ensureVisible(exerciseCard.first);
    await tester.tap(exerciseCard.first);
    await tester.pumpAndSettle();

    expect(find.text('Ultimo massimale: 120 kg'), findsNWidgets(3));
    final kgField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey &&
          widget.key.toString().contains('_0_kg'),
    );
    await tester.enterText(kgField, '100');
    await tester.pump();

    expect(
      find.text('Ultimo massimale: 120 kg · 83.3%'),
      findsOneWidget,
    );
  });

  testWidgets('Conditioning mostra durata e modalita collegate al main',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.lightMode,
      platformBrightness: Brightness.light,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('conditioning_hiit'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('selected_mode_description')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('conditioning_duration_slider')),
      findsOneWidget,
    );
    expect(find.text('30 min'), findsOneWidget);
    expect(find.textContaining('lavoro 20 min'), findsOneWidget);
    expect(find.text('Circuito a tempo'), findsWidgets);

    final intervalsChip = find.widgetWithText(
      ChoiceChip,
      'Intervalli lavoro / recupero',
    );
    await tester.ensureVisible(intervalsChip);
    await tester.tap(intervalsChip);
    await tester.pumpAndSettle();

    expect(find.textContaining('30 s lavoro'), findsOneWidget);
  });

  testWidgets('Conditioning resta leggibile in tema scuro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.setThemeMode(
      AppTheme.darkMode,
      platformBrightness: Brightness.dark,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: WorkoutFlowScreen(
            activity: WorkoutCatalog.byId('conditioning_hiit'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Durata totale'), findsOneWidget);
    expect(find.textContaining('lavoro 20 min'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected_mode_description')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final themeCase in const [
    (ThemeMode.light, Brightness.light, AppTheme.lightMode),
    (ThemeMode.dark, Brightness.dark, AppTheme.darkMode),
  ]) {
    testWidgets(
        'velocita usa prove con distanza e tempo in tema ${themeCase.$1.name}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppTheme.setThemeMode(
        themeCase.$3,
        platformBrightness: themeCase.$2,
      );
      await tester.binding.setSurfaceSize(const Size(430, 900));
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeCase.$1,
            home: WorkoutFlowScreen(
              activity: WorkoutCatalog.byId('dryland_speed_agility'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PROVA'), findsOneWidget);
      expect(find.text('DIST. M'), findsOneWidget);
      expect(find.text('TEMPO S'), findsOneWidget);
      expect(find.text('KG'), findsNothing);
      expect(find.text('REP'), findsNothing);

      final drillCard = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.key is ValueKey &&
            widget.key.toString().contains('workout_block_'),
      );
      await tester.ensureVisible(drillCard.first);
      await tester.tap(drillCard.first);
      await tester.pumpAndSettle();

      expect(find.text('DISTANZA (M)'), findsOneWidget);
      expect(find.text('TEMPO (S)'), findsOneWidget);
      expect(find.text('Aggiungi prova'), findsOneWidget);
      expect(find.text('Aggiungi serie'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.key.toString().contains('_0_distance'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
