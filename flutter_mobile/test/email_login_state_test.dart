import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

class _Consent implements HealthConsentRepository {
  @override
  Future<HealthConsentDecision?> latest(String userId) async => null;
  @override
  Future<void> record(String userId, HealthConsentDecision decision) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = '11111111-1111-4111-8111-111111111111';
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<AppState> setup(Map<String, dynamic>? profile,
      {Completer<void>? profileStarted,
      Completer<void>? releaseProfile}) async {
    SharedPreferences.setMockInitialValues({});
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
    final state = AppState(healthConsentRepository: _Consent());
    await state.init();
    addTearDown(() async {
      if (releaseProfile != null && !releaseProfile.isCompleted) {
        releaseProfile.complete();
      }
      state.dispose();
      await Supabase.instance.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });
    return state;
  }

  final valid = {
    'id': owner,
    'role': 'athlete',
    'birth_date': '1995-01-15',
    'avatar_url': ''
  };
  test('password login keeps health notice pending and imports disabled',
      () async {
    final state = await setup(valid);
    await state.signInWithEmailAndPassword(
        'review@example.invalid', 'synthetic');
    expect(state.isLoggedIn, isTrue);
    expect(state.userProfile?.id, owner);
    expect(state.healthConsent.loaded, isTrue);
    expect(state.healthConsent.decision, isNull);
    expect(state.canImportHealthData, isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets('email entry reaches the ordinary consent gate ($brightness)',
        (tester) async {
      final state = await setup(valid);
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
                  : const AuthScreen()),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accedi con email'));
      await tester.tap(find.text('Accedi con email'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('email-login-email')), 'review@example.invalid');
      await tester.enterText(
          find.byKey(const Key('email-login-password')), 'synthetic');
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(state.isLoggedIn, isTrue);
      expect(find.byType(HealthConsentScreen), findsOneWidget);
      expect(state.canImportHealthData, isFalse);
      expect(find.text('Authenticated content'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  final invalid = <String, Map<String, dynamic>?>{
    'missing profile': null,
    'missing birth date': {...valid, 'birth_date': null},
    'under 14': {
      ...valid,
      'birth_date': DateTime.now().toIso8601String().split('T').first
    },
    'invalid role': {...valid, 'role': 'admin'},
    'other account profile': {
      ...valid,
      'id': '22222222-2222-4222-8222-222222222222'
    },
  };
  for (final fixture in invalid.entries) {
    test('rejects ${fixture.key} and removes authenticated session', () async {
      final state = await setup(fixture.value);
      await expectLater(
          state.signInWithEmailAndPassword(
              'review@example.invalid', 'synthetic'),
          throwsA(isA<AuthException>()));
      expect(state.isLoggedIn, isFalse);
      expect(state.userProfile, isNull);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(state.sessions, isEmpty);
      expect(state.canImportHealthData, isFalse);
      expect((await SharedPreferences.getInstance()).getBool('isLoggedIn'),
          isNull);
    });
  }

  test('a login profile arriving after account deletion cannot restore login',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final state =
        await setup(valid, profileStarted: started, releaseProfile: release);
    final login =
        state.signInWithEmailAndPassword('review@example.invalid', 'synthetic');
    final rejected = expectLater(login, throwsA(isA<AuthException>()));
    await started.future;
    expect(state.isLoggedIn, isFalse);
    await state.completeAccountDeletion(owner);
    release.complete();
    await rejected;
    expect(state.isLoggedIn, isFalse);
    expect(state.userProfile, isNull);
    expect(state.canImportHealthData, isFalse);
    expect(
        (await SharedPreferences.getInstance()).getBool('isLoggedIn'), isNull);
  });
}
