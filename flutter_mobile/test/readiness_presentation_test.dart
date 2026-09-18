import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/models/health_score_update.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/services/daily_strain_persistence_service.dart';
import 'package:flutter_mobile/widgets/health_score_notice_host.dart';
import 'package:flutter_mobile/widgets/readiness_overview_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('READINESS_CAPTURE');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
    if (capture) {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      final bytes = await File('build/readiness-preview/Lexend-Regular.ttf')
          .readAsBytes();
      await (FontLoader('ReadinessPreview')
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('loading, scores and notice in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      if (capture) {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = true);
      }
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            brightness: brightness,
            fontFamily: capture ? 'ReadinessPreview' : null),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: brightness == Brightness.dark
                ? const Color(0xFF0F1115)
                : const Color(0xFFF5F7FA),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Readiness',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    const ReadinessOverviewCard(
                        metrics: ReadinessMetricData.placeholders,
                        readinessLabel: '',
                        insight: '',
                        isLoading: true,
                        progressLabel: 'Calcolo dei tuoi punteggi'),
                    const SizedBox(height: 26),
                    ReadinessOverviewCard(
                        metrics: _metrics(() => opened++),
                        readinessLabel: 'Readiness: Buono',
                        insight:
                            'Sonno e recupero favorevoli. Ascolta le tue sensazioni e segui il piano.'),
                    const SizedBox(height: 20),
                    HealthScoreReadyNotice(
                        update: _update(1),
                        onOpen: () => opened++,
                        onDismiss: () {}),
                  ]),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sonno'), findsNWidgets(2));
      expect(find.text('82'), findsOneWidget);
      expect(find.text('I tuoi punteggi sono pronti'), findsOneWidget);
      await tester.tap(find.text('82'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      if (capture) {
        await tester.runAsync(() async {
          final png = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final bytes = await png.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/readiness-verification')
            ..createSync(recursive: true);
          await File('${directory.path}/${brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          png.dispose();
        });
      }
      debugDisableShadows = true;
    });

    testWidgets(
        'narrow layout, large text and reduced motion in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8), disableAnimations: true),
          child: Scaffold(
              body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const ReadinessOverviewCard(
                  metrics: ReadinessMetricData.placeholders,
                  readinessLabel: '',
                  insight: '',
                  isLoading: true),
              ReadinessOverviewCard(
                  metrics: _metrics(() {}),
                  readinessLabel: '',
                  insight: '',
                  isRefreshing: true),
            ]),
          )),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('Aggiorniamo i tuoi punteggi'), findsOneWidget);
    });
  }

  testWidgets('an available strain stays visible while sleep and recovery load',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReadinessOverviewCard(
      metrics: [
        ReadinessMetricData.placeholders[0],
        _metrics(() {})[1],
        ReadinessMetricData.placeholders[2]
      ],
      readinessLabel: '',
      insight: '',
      isRefreshing: true,
    ))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('46'), findsOneWidget);
    expect(find.text('--'), findsNothing);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'completion appears above another route, is announced once and opens scores',
      (tester) async {
    final state = _NoticeState();
    final navigator = GlobalKey<NavigatorState>();
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => HealthScoreNoticeHost(
          state: state, onOpenScores: () => opened++, child: child!),
      home: const Scaffold(body: Text('Home')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Allenamenti'))));
    await tester.pumpAndSettle();
    state.emit(_update(1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Allenamenti'), findsOneWidget);
    expect(find.text('I tuoi punteggi sono pronti'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dismiss_health_score_notice')));
    await tester.pumpAndSettle();
    state.emit(_update(1));
    await tester.pumpAndSettle();
    expect(find.text('I tuoi punteggi sono pronti'), findsNothing);
    state.emit(_update(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vedi i punteggi'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(HealthScoreReadyNotice), findsNothing);
    state.emit(HealthScoreUpdate(
        revision: 3,
        dateKey: localDateKey(DateTime.now()),
        sleepScore: 82,
        recoveryScore: 78,
        systemNotificationShown: true));
    await tester.pumpAndSettle();
    expect(find.byType(HealthScoreReadyNotice), findsNothing);
  });

  testWidgets(
      'background completion with notifications disabled waits for the foreground',
      (tester) async {
    final state = _NoticeState();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => HealthScoreNoticeHost(
            state: state, onOpenScores: () {}, child: child!),
        home: const Scaffold()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    state.emit(_update(1, recovery: null));
    await tester.pump();
    await tester.pump();
    expect(find.byType(HealthScoreReadyNotice), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Il punteggio del sonno è pronto'), findsOneWidget);
    expect(find.textContaining('servono ancora dati'), findsOneWidget);
    state.loggedIn = false;
    state.emit(null);
    await tester.pumpAndSettle();
    expect(find.byType(HealthScoreReadyNotice), findsNothing);
  });
}

List<ReadinessMetricData> _metrics(VoidCallback onTap) => [
      ReadinessMetricData(
          icon: Icons.nightlight_round,
          title: 'Sonno',
          label: '82',
          caption: 'Buono',
          value: .82,
          color: const Color(0xFF7564D8),
          secondaryColor: const Color(0xFFA59AFF),
          onTap: onTap),
      const ReadinessMetricData(
          icon: Icons.local_fire_department_rounded,
          title: 'Sforzo',
          label: '46',
          caption: 'Moderato',
          value: .46,
          color: Color(0xFFEFA15A),
          secondaryColor: Color(0xFFFFBE81)),
      const ReadinessMetricData(
          icon: Icons.favorite_rounded,
          title: 'Recupero',
          label: '78',
          caption: 'Buono',
          value: .78,
          color: Color(0xFF30BBA2),
          secondaryColor: Color(0xFF73D8C2)),
    ];

HealthScoreUpdate _update(int revision, {double? recovery = 78}) =>
    HealthScoreUpdate(
        revision: revision,
        dateKey: localDateKey(DateTime.now()),
        sleepScore: 82,
        recoveryScore: recovery);

class _NoticeState extends AppState {
  bool loggedIn = true;
  HealthScoreUpdate? update;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  HealthScoreUpdate? get lastHealthScoreUpdate => update;
  void emit(HealthScoreUpdate? value) {
    update = value;
    notifyListeners();
  }
}
