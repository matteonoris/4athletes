import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/auth_screen.dart';
import 'package:flutter_mobile/screens/health_consent_screen.dart';
import 'package:flutter_mobile/services/health_consent_service.dart';
import 'package:flutter_mobile/widgets/health_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/native_apple_button.dart';

class _Consent implements HealthConsentRepository {
  @override
  Future<HealthConsentDecision?> latest(String userId) async => null;
  @override
  Future<void> record(String userId, HealthConsentDecision decision) async {}
}

class _SocialState extends AppState {
  _SocialState() : super(healthConsentRepository: _Consent());
  @override
  bool get isAppleSignInAvailable => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = '11111111-1111-4111-8111-111111111111';
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var profileWrites = 0;
  Future<AppState> setup(Map<String, dynamic>? profile,
      {Completer<void>? authStarted,
      Completer<void>? releaseAuth,
      Completer<void>? profileStarted,
      Completer<void>? releaseProfile}) async {
    SharedPreferences.setMockInitialValues({});
    profileWrites = 0;
    dotenv.loadFromString(envString: 'GOOGLE_WEB_CLIENT_ID=synthetic-client');
    const google = MethodChannel('plugins.flutter.io/google_sign_in');
    const apple =
        MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
    messenger.setMockMethodCallHandler(google, (call) async {
      if (call.method == 'signIn') {
        return {
          'id': 'synthetic-google',
          'email': 'legacy@example.invalid',
          'displayName': 'Legacy Athlete',
          'photoUrl': null,
        };
      }
      if (call.method == 'getTokens') {
        return {
          'idToken': 'synthetic-google-id',
          'accessToken': 'synthetic-access',
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
        apple,
        (call) async => {
              'type': 'appleid',
              'userIdentifier': 'synthetic-apple',
              'authorizationCode': 'synthetic-code',
              'identityToken': 'synthetic-apple-id',
              'email': null,
              'givenName': null,
              'familyName': null,
            });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'initialize' ? true : null);
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final token = '${base64UrlEncode(utf8.encode('{}'))}.'
        '${base64UrlEncode(utf8.encode(jsonEncode({
          'sub': owner,
          'exp': expiry
        })))}.mock';
    final client = MockClient((request) async {
      Object data = [];
      if (request.url.path == '/auth/v1/token') {
        if (authStarted != null && !authStarted.isCompleted) {
          authStarted.complete();
        }
        if (releaseAuth != null) await releaseAuth.future;
        data = {
          'access_token': token,
          'refresh_token': 'synthetic-refresh',
          'expires_in': 3600,
          'expires_at': expiry,
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'email': 'review@example.invalid',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z'
          }
        };
      } else if (request.url.path == '/rest/v1/profiles') {
        if (request.method != 'GET') profileWrites++;
        if (profileStarted != null && !profileStarted.isCompleted) {
          profileStarted.complete();
        }
        if (releaseProfile != null) {
          await releaseProfile.future;
        }
        data = profile == null ? [] : [profile];
      }
      return http.Response(jsonEncode(data), 200,
          headers: {'content-type': 'application/json'}, request: request);
    });
    await Supabase.initialize(
        url: 'https://synthetic.invalid',
        anonKey: 'synthetic',
        httpClient: client,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
    final state = _SocialState();
    await state.init();
    addTearDown(() async {
      if (releaseAuth != null && !releaseAuth.isCompleted) {
        releaseAuth.complete();
      }
      if (releaseProfile != null && !releaseProfile.isCompleted) {
        releaseProfile.complete();
      }
      state.dispose();
      await Supabase.instance.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(google, null);
      messenger.setMockMethodCallHandler(apple, null);
    });
    return state;
  }

  final legacy = <String, dynamic>{
    'id': owner,
    'role': 'athlete',
    'birth_date': '1995-01-15',
    'gender': null,
    'avatar_url': '',
    'first_name': 'Legacy',
    'last_name': 'Athlete',
  };
  for (final provider in ['Google', 'Apple']) {
    Future<AuthResponse?> login(AppState state) => provider == 'Google'
        ? state.signInWithGoogle()
        : state.signInWithApple();

    test('$provider legacy profile survives logout and signs in without signup',
        () async {
      final state = await setup(legacy);
      for (var attempt = 0; attempt < 2; attempt++) {
        await login(state);
        expect(state.isLoggedIn, isTrue);
        expect(state.isNewSocialUser, isFalse);
        expect(state.userProfile?.id, owner);
        expect(state.userProfile?.birthDate, '1995-01-15');
        expect(state.userProfile?.gender, isNull);
        expect(state.canImportHealthData, isFalse);
        expect(profileWrites, 0);
        await state.logout();
        expect(state.isLoggedIn, isFalse);
        expect(state.isNewSocialUser, isFalse);
      }
    });

    for (final fixture in <String, Map<String, dynamic>?>{
      'missing profile': null,
      'trigger row without age': {...legacy, 'birth_date': null},
    }.entries) {
      test('$provider ${fixture.key} still requires signup', () async {
        final state = await setup(fixture.value);
        await login(state);
        expect(state.isLoggedIn, isFalse);
        expect(state.isNewSocialUser, isTrue);
        expect(state.userProfile?.birthDate, isEmpty);
        expect(profileWrites, 0);
        await state.logout();
        expect(state.isNewSocialUser, isFalse);
      });
    }

    for (final fixture in {
      'under 14': {
        ...legacy,
        'birth_date': DateTime.now().toIso8601String().split('T').first
      },
      'invalid date': {...legacy, 'birth_date': 'invalid'},
      'invalid role': {...legacy, 'role': 'admin'},
      'other account': {
        ...legacy,
        'id': '22222222-2222-4222-8222-222222222222'
      },
    }.entries) {
      test('$provider rejects ${fixture.key} without signup fallback',
          () async {
        final state = await setup(fixture.value);
        await expectLater(login(state), throwsA(isA<AuthException>()));
        expect(state.isLoggedIn, isFalse);
        expect(state.isNewSocialUser, isFalse);
        expect(state.userProfile, isNull);
        expect(Supabase.instance.client.auth.currentSession, isNull);
        expect(profileWrites, 0);
      });
    }

    test('$provider late profile after logout cannot restore login', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final state =
          await setup(legacy, profileStarted: started, releaseProfile: release);
      final pending = login(state);
      final rejected = expectLater(pending, throwsA(isA<AuthException>()));
      await started.future;
      await state.logout();
      release.complete();
      await rejected;
      expect(state.isLoggedIn, isFalse);
      expect(state.userProfile, isNull);
      expect(state.isNewSocialUser, isFalse);
      expect(profileWrites, 0);
    });

    test('$provider late authentication after logout leaves no session',
        () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final state =
          await setup(legacy, authStarted: started, releaseAuth: release);
      final rejected = expectLater(login(state), throwsA(isA<AuthException>()));
      await started.future;
      await state.logout();
      release.complete();
      await rejected;
      expect(state.isLoggedIn, isFalse);
      expect(state.userProfile, isNull);
      expect(state.isNewSocialUser, isFalse);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('$provider legacy account skips signup in $brightness',
          (tester) async {
        mockNativeAppleButton();
        final state = await setup(legacy);
        AppTheme.setThemeMode(brightness == Brightness.dark
            ? AppTheme.darkMode
            : AppTheme.lightMode);
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                home: Consumer<AppState>(
                    builder: (_, state, __) => state.isLoggedIn
                        ? const HealthConsentGate(
                            child: Text('Authenticated content'))
                        : const AuthScreen()))));
        await tester.pumpAndSettle();
        if (provider == 'Apple') {
          await pressNativeAppleButton(tester);
        } else {
          await tester.ensureVisible(find.text('Continua con $provider'));
          await tester.tap(find.text('Continua con $provider'));
        }
        await tester.pumpAndSettle();
        expect(state.isLoggedIn, isTrue);
        expect(state.isNewSocialUser, isFalse);
        expect(find.text('Chi sei?'), findsNothing);
        expect(find.text('I tuoi dati'), findsNothing);
        expect(find.byType(HealthConsentScreen), findsOneWidget);
        expect(profileWrites, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
