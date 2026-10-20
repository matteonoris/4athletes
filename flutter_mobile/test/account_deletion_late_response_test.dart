import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_mobile/providers/app_state.dart';
import 'package:flutter_mobile/services/health_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Consent implements HealthConsentRepository {
  @override
  Future<HealthConsentDecision?> latest(String userId) async =>
      HealthConsentDecision.declined;
  @override
  Future<void> record(String userId, HealthConsentDecision decision) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a profile response received after deletion cannot restore local data',
      () async {
    const owner = '11111111-1111-4111-8111-111111111111';
    final started = Completer<void>();
    final releaseProfile = Completer<void>();
    var profileReads = 0;
    http.Response profile(http.Request request, String name) => http.Response(
        jsonEncode([
          {
            'id': owner,
            'first_name': name,
            'role': 'athlete',
            'birth_date': '2000-01-01',
            'gender': 'M',
            'avatar_url': '',
          }
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request);
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final token = '${base64UrlEncode(utf8.encode('{}'))}.'
        '${base64UrlEncode(utf8.encode(jsonEncode({
          'sub': owner,
          'exp': expiry
        })))}.mock';
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'synthetic-refresh',
              'expires_in': 3600,
              'expires_at': expiry,
              'token_type': 'bearer',
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'email': 'synthetic@example.invalid',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z'
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }
      if (request.url.path == '/rest/v1/profiles') {
        profileReads++;
        if (profileReads == 1) {
          return profile(request, 'Initial personal profile');
        }
        if (!started.isCompleted) started.complete();
        await releaseProfile.future;
        return profile(request, 'Late personal profile');
      }
      return http.Response('[]', 200,
          headers: {'content-type': 'application/json'}, request: request);
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications,
            (call) async => call.method == 'initialize' ? true : null);
    await Supabase.initialize(
        url: 'https://synthetic.invalid',
        anonKey: 'synthetic',
        httpClient: client,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
    final state = AppState(healthConsentRepository: _Consent());
    try {
      await state.init();
      await state.signInWithEmailAndPassword(
          'synthetic@example.invalid', 'synthetic-password');
      // Prove the fixture loads successfully before testing invalidation.
      expect(state.userProfile?.firstName, 'Initial personal profile');
      expect(state.isLoggedIn, isTrue);
      final loading = state.refreshTeams();
      await started.future.timeout(const Duration(seconds: 5));
      expect(state.userId, owner);
      await state.completeAccountDeletion(owner);
      releaseProfile.complete();
      await loading;
      expect(state.userProfile, isNull);
      expect(state.isLoggedIn, isFalse);
      expect(state.userId, isEmpty);
      expect(state.sessions, isEmpty);
      expect(state.bodyLogs, isEmpty);
      expect(state.canImportHealthData, isFalse);
      expect((await SharedPreferences.getInstance()).getBool('isLoggedIn'),
          isNull);
    } finally {
      if (!releaseProfile.isCompleted) releaseProfile.complete();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifications, null);
      state.dispose();
      await Supabase.instance.dispose();
    }
  });
}
