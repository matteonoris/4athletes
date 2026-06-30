import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/dev_flags.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/coach_dashboard_screen.dart';
import 'services/training_reminder_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica le variabili d'ambiente
  await dotenv.load(fileName: ".env");

  // Inizializza Supabase. If env is missing/placeholder, init with a placeholder
  // URL so Supabase.instance.client doesn't throw — calls will fail at runtime
  // instead of crashing the app at startup.
  final envUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final envAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final hasRealConfig = envUrl.isNotEmpty &&
      envAnonKey.isNotEmpty &&
      envUrl != 'inserisci_il_tuo_url_qui' &&
      envAnonKey != 'inserisci_la_tua_anon_key_qui';

  if (!hasRealConfig) {
    debugPrint(
        "ATTENZIONE: Variabili d'ambiente Supabase non configurate correttamente nel file .env");
  }

  await Supabase.initialize(
    url: hasRealConfig ? envUrl : 'https://placeholder.supabase.co',
    anonKey: hasRealConfig
        ? envAnonKey
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.placeholder',
  );

  final appState = AppState();
  await TrainingReminderNotificationService.instance.initialize();
  await appState.init();
  await TrainingReminderNotificationService.instance.syncForProfile(
    appState.userProfile,
    bodyLogs: appState.bodyLogs,
  );
  await initializeDateFormatting('it', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
      ],
      child: const FourAthletesApp(),
    ),
  );
}

class FourAthletesApp extends StatefulWidget {
  const FourAthletesApp({super.key});

  @override
  State<FourAthletesApp> createState() => _FourAthletesAppState();
}

class _FourAthletesAppState extends State<FourAthletesApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized =
        context.select<AppState, bool>((state) => state.isInitialized);
    final isLoggedIn =
        context.select<AppState, bool>((state) => state.isLoggedIn);
    final userRole = context.select<AppState, String?>(
      (state) => state.userProfile?.role,
    );
    final themeMode = context.select<AppState, String>(
      (state) => state.themeMode,
    );

    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    AppTheme.setThemeMode(
      themeMode,
      platformBrightness: platformBrightness,
    );

    if (!isInitialized) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppTheme.background,
          body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      );
    }

    return MaterialApp(
      title: '4athletes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.toFlutterThemeMode(themeMode),
      home: kOnboardingPreviewMode
          ? const AuthScreen()
          : isLoggedIn
              ? (userRole == 'coach'
                  ? const CoachDashboardScreen()
                  : const HomeScreen())
              : const AuthScreen(),
    );
  }
}
