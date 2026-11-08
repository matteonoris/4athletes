import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/signup_age.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/screens/auth_screen.dart';
import 'package:flutter_mobile/screens/email_login_screen.dart';
import 'package:flutter_mobile/widgets/health_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/native_apple_button.dart';

class _SignupState extends AppState {
  int googleCalls = 0;
  int appleCalls = 0;
  int profileSaves = 0;
  bool isNewUser = true;

  @override
  bool get isAppleSignInAvailable => true;

  @override
  bool get isNewGoogleUser => isNewUser;

  @override
  bool get isNewAppleUser => isNewUser;

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
    Future<_SignupState> openAuth(WidgetTester tester,
        {bool isNewUser = true, Size viewport = const Size(390, 844)}) async {
      mockNativeAppleButton();
      AppTheme.setThemeMode(brightness == Brightness.dark
          ? AppTheme.darkMode
          : AppTheme.lightMode);
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = _SignupState()..isNewUser = isNewUser;
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

    testWidgets('iPad Apple button is as prominent as Google ($brightness)',
        (tester) async {
      final state = await openAuth(tester, viewport: const Size(834, 1194));
      final google = find.widgetWithText(ElevatedButton, 'Continua con Google');
      final apple = find.byType(UiKitView);
      expect(tester.getSize(apple).width, tester.getSize(google).width);
      expect(tester.getSize(apple).height,
          greaterThanOrEqualTo(tester.getSize(google).height));
      await pressNativeAppleButton(tester);
      await tester.pumpAndSettle();
      expect(state.appleCalls, 1);
      expect(find.text('Chi sei?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('email login is available without a birth date ($brightness)',
        (tester) async {
      final state = await openAuth(tester);
      expect(find.text('DATA DI NASCITA'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tapText(tester, 'Accedi con email');
      expect(find.byType(EmailLoginScreen), findsOneWidget);
      expect(find.byKey(const Key('email-login-email')), findsOneWidget);
      expect(find.byKey(const Key('email-login-password')), findsOneWidget);
      expect(find.text('DATA DI NASCITA'), findsNothing);
      expect(state.googleCalls + state.appleCalls, 0);
      expect(state.profileSaves, 0);
      expect(tester.takeException(), isNull);
    });

    for (final provider in ['Google', 'Apple']) {
      testWidgets(
          '$provider starts signup without a birth date and checks it in personal details ($brightness)',
          (tester) async {
        final state = await openAuth(tester);
        expect(find.byType(TextFormField), findsNothing);
        if (provider == 'Apple') {
          await pressNativeAppleButton(tester);
          await tester.pumpAndSettle();
        } else {
          await tapText(tester, 'Continua con $provider');
        }
        expect(state.googleCalls, provider == 'Google' ? 1 : 0);
        expect(state.appleCalls, provider == 'Apple' ? 1 : 0);
        expect(find.text('Chi sei?'), findsOneWidget);
        expect(find.text('DATA DI NASCITA'), findsNothing);
        await tapText(tester, 'Avanti');
        expect(find.text('I tuoi dati'), findsOneWidget);
        expect(find.text('DATA DI NASCITA'), findsOneWidget);
        await tapText(tester, 'M');
        await tapText(tester, 'Avanti');
        expect(
            find.text('Seleziona una data di nascita valida.'), findsOneWidget);
        expect(find.text('I tuoi dati'), findsOneWidget);

        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        tester
            .widget<TextFormField>(find.ancestor(
                of: find.byWidgetPredicate(
                    (widget) => widget is TextField && widget.readOnly),
                matching: find.byType(TextFormField)))
            .controller!
            .text = _dateAtAge(13);
        await tapText(tester, 'Avanti');
        expect(find.text(minimumSignupAgeMessage), findsOneWidget);
        expect(find.text('I tuoi dati'), findsOneWidget);
        expect(state.profileSaves, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$provider existing users skip signup ($brightness)',
          (tester) async {
        final state = await openAuth(tester, isNewUser: false);
        if (provider == 'Apple') {
          await pressNativeAppleButton(tester);
        } else {
          await tester.tap(find.text('Continua con $provider'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(state.googleCalls, provider == 'Google' ? 1 : 0);
        expect(state.appleCalls, provider == 'Apple' ? 1 : 0);
        expect(find.byType(AuthScreen), findsNothing);
        expect(find.text('Chi sei?'), findsNothing);
        expect(find.text('DATA DI NASCITA'), findsNothing);
        expect(find.byType(HealthConsentGate), findsOneWidget);
        expect(
            tester
                .widget<HealthConsentGate>(find.byType(HealthConsentGate))
                .existingUser,
            isTrue);
        expect(state.profileSaves, 0);
        expect(tester.takeException(), isNull);
      });
    }

    for (final role in ['Atleta', 'Allenatore']) {
      testWidgets(
          '14th birthday passes and age is checked again for $role ($brightness)',
          (tester) async {
        final state = await openAuth(tester);
        await tapText(tester, 'Continua con Google');
        expect(state.googleCalls, 1);
        expect(find.text('Chi sei?'), findsOneWidget);
        await tapText(tester, role);
        await tapText(tester, 'Avanti');
        await tapText(tester, 'M');
        final birthController = tester
            .widget<TextFormField>(find.ancestor(
                of: find.byWidgetPredicate(
                    (widget) => widget is TextField && widget.readOnly),
                matching: find.byType(TextFormField)))
            .controller!;

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
        if (role == 'Atleta') {
          await tapText(tester, 'Salta per ora');
        }
        expect(find.text('Foto profilo'), findsOneWidget);
        final completeLabel = role == 'Allenatore' ? 'Completa' : 'Avanti';
        birthController.text = _dateAtAge(13);
        for (final label in [completeLabel, 'Salta per ora']) {
          await tapText(tester, label);
          expect(state.profileSaves, 0);
          expect(find.text(minimumSignupAgeMessage), findsOneWidget);
          tester
              .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
              .removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
        birthController.text = '';
        await tapText(tester, completeLabel);
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
}
