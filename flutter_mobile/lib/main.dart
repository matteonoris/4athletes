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

  // Inizializza Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && supabaseUrl != 'inserisci_il_tuo_url_qui') {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    debugPrint("ATTENZIONE: Variabili d'ambiente Supabase non configurate correttamente nel file .env");
  }

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
