import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/coach_dashboard_screen.dart';
import 'package:flutter_mobile/screens/home_screen.dart';
import 'package:flutter_mobile/screens/notifications_screen.dart';
import 'package:flutter_mobile/screens/ski_activity_screen.dart';
import 'package:flutter_mobile/widgets/bottom_nav.dart';
import 'package:flutter_mobile/widgets/custom_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _UiTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => !const bool.fromEnvironment('UI_CAPTURE');
}

class _PreviewState extends AppState {
  _PreviewState({String role = 'athlete'})
      : previewProfile = UserProfile(
          firstName: 'Andrea',
          lastName: 'Rossi',
          email: 'preview@example.com',
          birthDate: '2000-01-01',
          role: role,
          weight: 72,
          height: 178,
          maxHr: 195,
          unitSystem: 'metric',
          language: 'it',
          avatarUrl: '',
          notificationsEnabled: false,
          connectedDevices: const [],
        );
  final UserProfile previewProfile;
  @override
  UserProfile get userProfile => previewProfile;
  @override
  UserProfile get profile => previewProfile;
  @override
  double? sleepScoreForDate(DateTime date) => 82;
  @override
  double? recoveryScoreForDate(DateTime date) => 76;
  @override
  double? strainScoreForDate(DateTime date) => 46;
  @override
  Future<void> syncDailyHealthData(DateTime date,
      {bool forceRefresh = false,
      int? healthRequestId,
      bool requestPermissions = true}) async {}
  @override
  Future<void> refreshHealthDataIfStale([DateTime? date]) async {}
  @override
  List<AppNotification> get notifications => [
        AppNotification(
          id: 'preview',
          title: 'Allenamento di domani',
          message: 'La sessione di slalom è pronta nel calendario.',
          timestamp: '2026-09-16',
        )
      ];
}

void main() {
  _UiTestBinding();
  const capture = bool.fromEnvironment('UI_CAPTURE');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('it');
    await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
    final loader = FontLoader('Lexend');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Lexend-$weight.ttf'));
    }
    await loader.load();
    if (capture) {
      await Directory('build/ui-review').create(recursive: true);
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      await (FontLoader('packages/phosphor_flutter/PhosphorRegular')
            ..addFont(rootBundle
                .load('packages/phosphor_flutter/lib/fonts/Phosphor.ttf')))
          .load();
    }
  });
  setUp(() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      original?.call(details);
    };
  });

  for (final brightness in Brightness.values) {
    Future<void> mount(
        WidgetTester tester, Widget screen, _PreviewState state) async {
      AppTheme.setThemeMode(brightness.name);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: RepaintBoundary(
            key: const ValueKey('ui_capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
              home: screen,
            )),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> snapshot(WidgetTester tester, String name) async {
      if (capture) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('ui_capture')));
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/ui-review/$name-${brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    }

    testWidgets('athlete navigation and screens in ${brightness.name}',
        (tester) async {
      final state = _PreviewState();
      await mount(tester, const HomeScreen(), state);
      await snapshot(tester, 'home');
      for (final label in ['Analytics', 'Salute', 'Team', 'Profilo', 'Home']) {
        await tester.tap(find.descendant(
            of: find.byType(NavigationBar), matching: find.text(label)));
        await tester.pumpAndSettle();
        await snapshot(tester, label.toLowerCase());
      }
      expect(find.text('82'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });

    testWidgets(
        'coach navigation preserves calendar actions in ${brightness.name}',
        (tester) async {
      final state = _PreviewState(role: 'coach');
      await mount(tester, const CoachDashboardScreen(), state);
      await snapshot(tester, 'coach');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Allenamento Sci'), findsOneWidget);
      expect(find.text('Preparazione Atletica'), findsOneWidget);
      expect(find.text('Test Atletici'), findsOneWidget);
      await snapshot(tester, 'coach-actions');
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });

    testWidgets('ski form and notifications in ${brightness.name}',
        (tester) async {
      final state = _PreviewState();
      await mount(tester, const SkiActivityScreen(), state);
      await snapshot(tester, 'ski');
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const NotificationsScreen(), state);
      final title = tester.widget<Text>(find.text('Allenamento di domani'));
      expect(title.style!.color, AppTheme.textHighEmphasis);
      await snapshot(tester, 'notifications');
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });

    testWidgets('compact navigation and card taps in ${brightness.name}',
        (tester) async {
      AppTheme.setThemeMode(brightness.name);
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int selected = -1;
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
              body: CustomCard(
                  onTap: () => taps++, child: const Text('Apri scheda')),
              bottomNavigationBar: BottomNav(
                  currentIndex: 0, onTap: (value) => selected = value)),
        ),
      ));
      await tester.tap(find.text('Apri scheda'));
      await tester.tap(find.text('Salute'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
