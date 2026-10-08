import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/signup_age.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SignupState extends AppState {
  int googleCalls = 0;
  int appleCalls = 0;
  int profileSaves = 0;

  @override
  bool get isAppleSignInAvailable => true;

  @override
  bool get isNewGoogleUser => true;

  @override
  bool get isNewAppleUser => true;

  AuthResponse get response => AuthResponse(
        user: User(
          id: 'age-test-user',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

  @override
  Future<AuthResponse?> signInWithGoogle() async {
    googleCalls++;
    return response;
  }

  @override
  Future<AuthResponse?> signInWithApple() async {
    appleCalls++;
    return response;
  }

  @override
  Future<void> login(UserProfile profile) async {
    profileSaves++;
  }
}

String _dateAtAge(int age) {
  final today = DateTime.now();
  return DateTime(today.year - age, today.month, today.day)
      .toIso8601String()
      .split('T')
      .first;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  for (final brightness in Brightness.values) {
    Future<_SignupState> openAuth(WidgetTester tester) async {
      AppTheme.setThemeMode(brightness == Brightness.dark
          ? AppTheme.darkMode
          : AppTheme.lightMode);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = _SignupState();
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: const AuthScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      addTearDown(state.dispose);
      return state;
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      final target = find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('missing birth date never starts OAuth ($brightness)',
        (tester) async {
      final state = await openAuth(tester);
      await tapText(tester, 'Continua con Google');
      expect(
          find.text('Seleziona una data di nascita valida.'), findsOneWidget);
      await tapText(tester, 'Continua con Apple');
      expect(state.googleCalls + state.appleCalls, 0);
      expect(state.profileSaves, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('under-14 users never start either OAuth flow ($brightness)',
        (tester) async {
      final state = await openAuth(tester);
      tester
          .widget<TextFormField>(find.byType(TextFormField))
          .controller!
          .text = _dateAtAge(13);
      await tapText(tester, 'Continua con Google');
      expect(find.text(minimumSignupAgeMessage), findsOneWidget);
      await tapText(tester, 'Continua con Apple');
      expect(state.googleCalls + state.appleCalls, 0);
      expect(state.profileSaves, 0);
      expect(find.text('Chi sei?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('14th birthday passes and age is checked again ($brightness)',
        (tester) async {
      final state = await openAuth(tester);
      final birthController =
          tester.widget<TextFormField>(find.byType(TextFormField)).controller!;
      birthController.text = _dateAtAge(14);
      await tapText(tester, 'Continua con Google');
      expect(state.googleCalls, 1);
      expect(find.text('Chi sei?'), findsOneWidget);
      await tapText(tester, 'Allenatore');
      await tapText(tester, 'Avanti');
      await tapText(tester, 'M');

      birthController.text = _dateAtAge(13);
      await tapText(tester, 'Avanti');
      expect(find.text('I tuoi dati'), findsOneWidget);
      expect(find.text(minimumSignupAgeMessage), findsOneWidget);
      expect(state.profileSaves, 0);

      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      birthController.text = _dateAtAge(14);
      await tapText(tester, 'Avanti');
      birthController.text = '';
      await tapText(tester, 'Completa');
      expect(state.profileSaves, 0);
      expect(
          find.text('Seleziona una data di nascita valida.'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tapText(tester, 'Salta per ora');
      expect(state.profileSaves, 0);
      expect(
          find.text('Seleziona una data di nascita valida.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
