import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/coach_dashboard_screen.dart';

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
    debugPrint("ATTENZIONE: Variabili d'ambiente Supabase non configurate correttamente nel file .env");
  }

  await Supabase.initialize(
    url: hasRealConfig ? envUrl : 'https://placeholder.supabase.co',
    anonKey: hasRealConfig
        ? envAnonKey
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.placeholder',
  );

  final appState = AppState();
  await appState.init();
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

class _FourAthletesAppState extends State<FourAthletesApp> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunchAndNotifications();
  }

  void _checkFirstLaunchAndNotifications() async {
    // In a real app we would use flutter_local_notifications and permission_handler here
    debugPrint("Initializing notification logic...");
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (!appState.isInitialized) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
            ),
          );
        }

        return MaterialApp(
          title: '4athletes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: appState.isLoggedIn
              ? (appState.userProfile?.role == 'coach'
                  ? const CoachDashboardScreen()
                  : const HomeScreen())
              : const AuthScreen(),
        );
      },
    );
  }
}
