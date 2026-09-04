import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/analytics_screen.dart';
import 'package:flutter_mobile/utils/analytics_performance_benchmarks.dart';
import 'package:flutter_mobile/utils/analytics_performance_colors.dart';
import 'package:flutter_mobile/widgets/custom_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _BenchmarkAnalyticsState extends AppState {
  final UserProfile _testProfile;
  final List<JumpLog> _testJumpLogs;
  final List<BodyMetricLog> _testBodyLogs;

  _BenchmarkAnalyticsState({
    required UserProfile profile,
    required List<JumpLog> jumpLogs,
    required List<BodyMetricLog> bodyLogs,
  })  : _testProfile = profile,
        _testJumpLogs = jumpLogs,
        _testBodyLogs = bodyLogs;

  @override
  UserProfile? get profile => _testProfile;

  @override
  List<JumpLog> get jumpLogs => _testJumpLogs;

  @override
  List<BodyMetricLog> get bodyLogs => _testBodyLogs;
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

  for (final brightness in Brightness.values) {
    testWidgets('colora le card rosso giallo verde in tema ${brightness.name}',
        (tester) async {
      final isDark = brightness == Brightness.dark;
      AppTheme.setThemeMode(
        isDark ? AppTheme.darkMode : AppTheme.lightMode,
        platformBrightness: brightness,
      );
      await tester.binding.setSurfaceSize(const Size(430, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = _BenchmarkAnalyticsState(
        profile: UserProfile(
          firstName: 'Atleta',
          lastName: 'Senior',
          email: 'athlete@example.com',
          birthDate: '1990-01-01',
          role: 'athlete',
          weight: 70,
          height: 175,
          maxHr: 190,
          unitSystem: 'metric',
          language: 'it',
          avatarUrl: '',
          notificationsEnabled: false,
          gender: 'M',
          connectedDevices: const [],
        ),
        jumpLogs: [
          JumpLog(
            id: 'sj',
            date: '2026-09-04',
            type: 'squat_jump',
            value: 43,
          ),
          JumpLog(
            id: 'cmj',
            date: '2026-09-04',
            type: 'cm_jump',
            value: 53,
          ),
          JumpLog(
            id: 'dj',
            date: '2026-09-04',
            type: 'drop_jump',
            value: 45,
          ),
          JumpLog(
            id: 'single-left',
            date: '2026-09-04',
            type: 'single_leg_left',
            value: 22,
          ),
          JumpLog(
            id: 'single-right',
            date: '2026-09-04',
            type: 'single_leg_right',
            value: 27,
          ),
        ],
        bodyLogs: [
          BodyMetricLog(
            id: '20m',
            date: '2026-09-04',
            type: 'sprint_20m',
            value: 3.17,
          ),
          BodyMetricLog(
            id: '60m',
            date: '2026-09-04',
            type: 'sprint_60m',
            value: 7.4,
          ),
          BodyMetricLog(
            id: 'vo2',
            date: '2026-09-04',
            type: 'leger_vo2max',
            value: 64,
          ),
          BodyMetricLog(
            id: 'balance-bi',
            date: '2026-09-04',
            type: 'balance_bipedal',
            value: 3.3,
          ),
          BodyMetricLog(
            id: 'balance-left',
            date: '2026-09-04',
            type: 'balance_single_l',
            value: 2.5,
          ),
          BodyMetricLog(
            id: 'balance-right',
            date: '2026-09-04',
            type: 'balance_single_r',
            value: 2,
          ),
          BodyMetricLog(
            id: 'pullups',
            date: '2026-09-04',
            type: 'pullups_max',
            value: 18,
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: const AnalyticsScreen(),
          ),
        ),
      );
      await tester.pump();

      CustomCard cardFor(String key) {
        return tester.widget<CustomCard>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(CustomCard),
          ),
        );
      }

      expect(
        cardFor('benchmark_card_squat_jump').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.negative,
        ),
      );
      expect(
        cardFor('benchmark_card_cm_jump').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.discrete,
        ),
      );
      expect(
        cardFor('benchmark_card_drop_jump').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.positive,
        ),
      );
      expect(
        cardFor('benchmark_card_45s_jump').color,
        isNull,
        reason: 'Una misura assente deve mantenere lo sfondo standard.',
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(
              const ValueKey('benchmark_card_single_leg_left'),
            ))
            .color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.negative,
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(
              const ValueKey('benchmark_card_single_leg_right'),
            ))
            .color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.positive,
        ),
      );
      expect(
        cardFor('benchmark_card_sprint_20m').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.negative,
        ),
      );
      expect(
        cardFor('benchmark_card_sprint_60m').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.discrete,
        ),
      );
      expect(
        cardFor('benchmark_card_leger_vo2max').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.positive,
        ),
      );
      expect(
        cardFor('benchmark_card_balance_bipedal').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.negative,
        ),
      );
      expect(
        cardFor('benchmark_card_balance_single_l').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.discrete,
        ),
      );
      expect(
        cardFor('benchmark_card_balance_single_r').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.positive,
        ),
      );
      expect(
        cardFor('benchmark_card_pullups_max').color,
        analyticsPerformanceCardColor(
          brightness,
          AnalyticsPerformanceBand.positive,
        ),
      );
      final neutralMaxLoad = tester.widget<CustomCard>(
        find.descendant(
          of: find.byKey(const ValueKey('max_load_back_squat')),
          matching: find.byType(CustomCard),
        ),
      );
      expect(
        neutralMaxLoad.color,
        isNull,
        reason: 'I massimali senza tabella devono restare neutri.',
      );
    });
  }
}
