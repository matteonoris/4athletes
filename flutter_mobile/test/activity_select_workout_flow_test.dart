import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/activity_select.dart';
import 'package:flutter_mobile/screens/ski_activity_screen.dart';
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
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.placeholder',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
    }
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String themeMode = AppTheme.darkMode,
  }) async {
    AppTheme.setThemeMode(
      themeMode,
      platformBrightness:
          themeMode == AppTheme.darkMode ? Brightness.dark : Brightness.light,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppTheme.toFlutterThemeMode(themeMode),
          home: const ActivitySelectScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('usa lista verticale senza griglie, recenti o preferiti',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('workout_activity_vertical_list')),
        findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Sport recenti'), findsNothing);
    expect(find.text('Sport preferiti'), findsNothing);
    expect(find.text('Mostra tutti gli sport'), findsNothing);
    expect(find.text('PREPARAZIONE ATLETICA'), findsOneWidget);
    expect(find.text('Forza'), findsOneWidget);
    expect(find.text('Pliometria'), findsOneWidget);
    expect(find.text('Velocità e agilità'), findsOneWidget);
    expect(find.text('Conditioning / HIIT'), findsOneWidget);
  });

  testWidgets('ricerca protocolli, modalita e sinonimi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await pumpScreen(tester);
    final search = find.byKey(const ValueKey('workout_activity_search'));

    await tester.enterText(search, '4x4');
    await tester.pump();
    expect(find.text('Norwegian 4x4'), findsOneWidget);
    expect(find.text('PROTOCOLLO'), findsWidgets);

    await tester.enterText(search, 'ripetute');
    await tester.pump();
    expect(find.text('Corsa · Intervalli / ripetute'), findsOneWidget);

    await tester.enterText(search, 'pesi');
    await tester.pump();
    expect(find.text('Forza'), findsOneWidget);
    expect(find.text('Powerlifting'), findsOneWidget);
    expect(find.text('Weightlifting'), findsOneWidget);

    await tester.enterText(search, 'circuito');
    await tester.pump();
    expect(find.text('Conditioning / HIIT'), findsOneWidget);
  });

  testWidgets('lista resta leggibile in tema chiaro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await pumpScreen(tester, themeMode: AppTheme.lightMode);

    expect(find.text('Aggiungi allenamento'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('workout_activity_search')), findsOneWidget);
    expect(find.text('Forza'), findsOneWidget);
  });

  testWidgets('sci alpino apre il form tecnico atleta dedicato',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('workout_activity_search')),
      'sci alpino',
    );
    await tester.pump();
    final alpine = find.byKey(const ValueKey('search_activity_alpine_skiing'));
    await tester.tap(alpine);
    await tester.pumpAndSettle();

    expect(find.byType(SkiActivityScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('ski_training_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('ski_double_specialty')), findsOneWidget);
    expect(find.text('Completato'), findsNothing);
    expect(find.text('Team'), findsNothing);
    expect(find.text('Atleti convocati'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ski_double_specialty')));
    await tester.pump();
    expect(find.text('SECONDA SPECIALITA'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ski_add_track_SL')), findsOneWidget);
    expect(find.byKey(const ValueKey('ski_add_training_SL')), findsOneWidget);
    expect(find.byKey(const ValueKey('ski_chrono_switch')), findsOneWidget);
  });

  testWidgets('form sci atleta resta leggibile in tema chiaro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await pumpScreen(tester, themeMode: AppTheme.lightMode);

    await tester.enterText(
      find.byKey(const ValueKey('workout_activity_search')),
      'sci alpino',
    );
    await tester.pump();
    final alpine = find.byKey(const ValueKey('search_activity_alpine_skiing'));
    await tester.tap(alpine);
    await tester.pumpAndSettle();

    expect(find.byType(SkiActivityScreen), findsOneWidget);
    expect(find.text('Alpine Skiing'), findsOneWidget);
    expect(find.byKey(const ValueKey('ski_save_button')), findsOneWidget);
  });
}
