import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health/health.dart';
import '../models/models.dart';
import '../services/health_service.dart';
import '../services/native_health_service.dart';
import '../services/health_sync_service.dart';
import '../utils/hrv_engine.dart';

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  final _supabase = Supabase.instance.client;

  String get userId =>
      _supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isNewGoogleUser = false;
  bool get isNewGoogleUser => _isNewGoogleUser;

  bool _isNewAppleUser = false;
  bool get isNewAppleUser => _isNewAppleUser;

  bool get isNewSocialUser => _isNewGoogleUser || _isNewAppleUser;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  UserProfile? get profile => _userProfile;

  List<TrainingSession> _sessions = [];
  List<TrainingSession> get sessions => _sessions;

  List<Team> _teams = [];
  List<Team> get teams => _teams;

  List<BodyMetricLog> _bodyLogs = [];
  List<BodyMetricLog> get bodyLogs => _bodyLogs;

  List<PRLog> _prLogs = [];
  List<PRLog> get prLogs => _prLogs;

  List<JumpLog> _jumpLogs = [];
  List<JumpLog> get jumpLogs => _jumpLogs;

  List<CalendarEvent> _coachEvents = [];
  List<CalendarEvent> get coachEvents => _coachEvents;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  final HealthSyncService _healthSyncService = HealthSyncService();

  double? _currentSleepScore;
  double? get currentSleepScore => _currentSleepScore;

  double? _currentRecoveryScore;
  double? get currentRecoveryScore => _currentRecoveryScore;

  Map<String, double>? _currentDailyMetrics;
  Map<String, double>? get currentDailyMetrics => _currentDailyMetrics;

  Map<String, List<double>>? _currentHistoricalMetrics;
  Map<String, List<double>>? get currentHistoricalMetrics =>
      _currentHistoricalMetrics;

  List<Map<String, dynamic>>? _currentLocalSleepHistory;
  List<Map<String, dynamic>>? get currentLocalSleepHistory => _currentLocalSleepHistory;

  bool _isSyncingHealth = false;
  bool get isSyncingHealth => _isSyncingHealth;

  bool _healthSyncCompleted = false;
  bool get healthSyncCompleted => _healthSyncCompleted;

  String? _healthSyncError;
  String? get healthSyncError => _healthSyncError;

  Future<void> syncDailyHealthData(DateTime targetDate) async {
    _isSyncingHealth = true;
    _healthSyncCompleted = false;
    _healthSyncError = null;
    notifyListeners();

    String dateKey = targetDate.toIso8601String().split('T')[0];

    // Sincronizza Peso esplicitamente in modo incondizionato
    try {
      final weightData = await Health().getHealthDataFromTypes(
        startTime: DateTime.now().subtract(const Duration(days: 7)),
        endTime: DateTime.now(),
        types: [HealthDataType.WEIGHT],
      );
      for (var point in weightData) {
        if (point.value is NumericHealthValue) {
          final val = (point.value as NumericHealthValue).numericValue;
          final dateStr = point.dateFrom.toIso8601String().split('T')[0];
          final exists =
              _bodyLogs.any((l) => l.type == 'weight' && l.date == dateStr);
          if (!exists) {
            addBodyLog(BodyMetricLog(
                id: 'weight_$dateStr',
                date: dateStr,
                type: 'weight',
                value: val.toDouble()));
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing weight in syncDailyHealthData: $e');
    }

    // Controlla la cache locale
    if (_prefs != null && _prefs!.containsKey('health_sync_v5_$dateKey')) {
      try {
        final cached = jsonDecode(_prefs!.getString('health_sync_v5_$dateKey')!);
        
        // Se il recoveryScore in cache è null, ignoriamo la cache e ricalcoliamo.
        // Questo permette di uscire dalla fase di calibrazione non appena ci sono nuovi dati,
        // o di applicare l'algoritmo corretto se c'era un bug precedentemente cachato.
        if (cached['recoveryScore'] != null) {
          _currentSleepScore = cached['sleepScore'];
          _currentRecoveryScore = cached['recoveryScore'];
          _currentDailyMetrics = Map<String, double>.from(cached['dailyMetrics']);
          _currentHistoricalMetrics =
              (cached['historicalMetrics'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<double>.from(value)),
          );
          if (cached['localSleepHistory'] != null) {
            _currentLocalSleepHistory = List<Map<String, dynamic>>.from(cached['localSleepHistory']);
          }
          _healthSyncCompleted = true;
          _isSyncingHealth = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        // Fallback al calcolo se la cache è corrotta
      }
    }

    try {
      // Assicuriamoci che i log corporei locali (Temp, SpO2, Resp) siano aggiornati prima di calcolare
      await syncDailyHealthMetrics();

      bool isLutealPhase = false; // TODO: Ottenere dal profilo utente
      final result = await _healthSyncService.fetchAndCalculateScores(isLutealPhase, _bodyLogs, targetDate);

      // Aggiorna lo stato
      _currentSleepScore = result.sleepScore;
      _currentRecoveryScore = result.recoveryScore;
      _currentDailyMetrics = result.dailyMetrics;
      _currentHistoricalMetrics = result.historicalMetrics;
      _currentLocalSleepHistory = result.localSleepHistory;

      if (_currentRecoveryScore == null) {
        _healthSyncError = "CALIBRATION_PHASE";
      }

      // Sync sleep_score to Supabase
      try {
        final exists = _bodyLogs.any((l) => l.type == 'sleep_score' && l.date == dateKey);
        if (!exists) {
          final newLog = BodyMetricLog(
            id: 'sleep_score_$dateKey',
            date: dateKey,
            type: 'sleep_score',
            value: _currentSleepScore!,
          );
          addBodyLog(newLog);
        }
      } catch (e) {
        debugPrint('Error syncing sleep_score: $e');
      }

      _healthSyncCompleted = true;

      // Salva in cache
      if (_prefs != null) {
        _prefs!.setString(
            'health_sync_v5_$dateKey',
            jsonEncode({
              'sleepScore': _currentSleepScore,
              'recoveryScore': _currentRecoveryScore,
              'dailyMetrics': _currentDailyMetrics,
              'historicalMetrics': _currentHistoricalMetrics,
              'localSleepHistory': _currentLocalSleepHistory,
            }));
      }
    } on PlatformException catch (e) {
      if (e.message?.contains('Health Connect') == true ||
          e.code == 'Health Connect non installato') {
        _healthSyncError = "HEALTH_CONNECT_NOT_INSTALLED";
      } else {
        _healthSyncError = e.message;
      }
    } catch (e) {
      String errStr = e.toString();
      if (errStr.contains('CALIBRATION_PHASE')) {
        _healthSyncError = "CALIBRATION_PHASE";
      } else if (errStr.contains('Health Connect')) {
        _healthSyncError = "HEALTH_CONNECT_NOT_INSTALLED";
      } else {
        _healthSyncError = errStr;
      }
    } finally {
      _isSyncingHealth = false;
      notifyListeners();
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _isLoggedIn = _prefs!.getBool('isLoggedIn') ?? false;

    if (_isLoggedIn) {
      await _loadAllData();
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadAllData() async {
    await _loadUserProfile();
    await _loadSessions();
    await _loadTeams();
    await _loadBodyLogs();
    await _loadPrLogs();
    await _loadJumpLogs();
    await _loadCoachEvents();
    await _loadNotifications();
  }

  void login(UserProfile profile) async {
    _userProfile = profile;
    _isLoggedIn = true;
    _prefs!.setBool('isLoggedIn', true);
    await _saveUserProfile();
    await _loadAllData();
    notifyListeners();
  }

  void logout() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,
        serverClientId: kIsWeb ? null : webClientId,
      );
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out of Google: $e');
    }

    await _supabase.auth.signOut();
    _isLoggedIn = false;
    _prefs!.remove('isLoggedIn');
    _userProfile = null;
    _sessions.clear();
    _teams.clear();
    _bodyLogs.clear();
    _prLogs.clear();
    _jumpLogs.clear();
    _coachEvents.clear();
    _notifications.clear();
    notifyListeners();
  }

  Future<AuthResponse?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        _isLoggedIn = true;
        _prefs!.setBool('isLoggedIn', true);
        await _loadAllData();
        notifyListeners();
      }
      return response;
    } catch (e) {
      debugPrint('Error signing in with Email/Password: $e');
      rethrow;
    }
  }

  Future<AuthResponse?> signUpWithEmailAndPassword(
      String email, String password, UserProfile profile) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Il nuovo utente non ha ancora un profilo su Supabase (viene creato via trigger, o salvato manualmente)
        _userProfile = profile;
        _isLoggedIn = true;
        _prefs!.setBool('isLoggedIn', true);
        await _saveUserProfile();
        await _loadAllData();
        notifyListeners();
      }
      return response;
    } catch (e) {
      debugPrint('Error signing up with Email/Password: $e');
      rethrow;
    }
  }

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

      if (!kIsWeb &&
          Platform.isIOS &&
          (iosClientId == null || iosClientId.isEmpty)) {
        throw 'Google Sign-In non è ancora configurato per iOS. Aggiungi GOOGLE_IOS_CLIENT_ID nel .env per abilitarlo.';
      }

      final String? clientIdForPlatform =
          kIsWeb ? webClientId : (Platform.isIOS ? iosClientId : null);

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: clientIdForPlatform,
        serverClientId: kIsWeb ? null : webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // The GoogleSignIn iOS SDK 8.x auto-adds a nonce to the id_token that
      // google_sign_in 6.x can't expose. Supabase project must have
      // "Skip nonce check" enabled for the Google provider for this to work.
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        // Fetch or create profile
        final userId = response.user!.id;
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (profileData == null) {
          _isNewGoogleUser = true;
          // Create a temp profile to be completed
          _userProfile = UserProfile(
            firstName: googleUser.displayName?.split(' ').first ?? 'New',
            lastName: googleUser.displayName?.split(' ').last ?? 'User',
            email: googleUser.email,
            birthDate: '', // Empty, so it can be requested
            role: 'athlete',
            weight: 0.0,
            height: 0.0,
            maxHr: 0,
            avatarUrl: googleUser.photoUrl ?? '',
            unitSystem: 'metric',
            language: 'it',
            notificationsEnabled: true,
            connectedDevices: [],
            oneRepMax: {},
          );
          // Do NOT save to db or set isLoggedIn=true yet
        } else {
          _isNewGoogleUser = false;
          // Load existing profile
          _userProfile = UserProfile(
            firstName: profileData['first_name'] ?? '',
            lastName: profileData['last_name'] ?? '',
            email: profileData['email'] ?? '',
            birthDate: profileData['birth_date'] ?? '2000-01-01',
            role: profileData['role'] ?? 'athlete',
            weight: (profileData['weight'] as num?)?.toDouble() ?? 70.0,
            height: (profileData['height'] as num?)?.toDouble() ?? 175.0,
            maxHr: profileData['max_hr'] ?? 190,
            avatarUrl: profileData['avatar_url'] ?? '',
            unitSystem: _prefs!.getString('unitSystem') ?? 'metric',
            language: _prefs!.getString('language') ?? 'it',
            notificationsEnabled:
                _prefs!.getBool('notificationsEnabled') ?? true,
            connectedDevices: [],
            oneRepMax: {},
            teamId: profileData['team_id'],
            hrZoneMode: profileData['hr_zone_mode'] ?? 'standard',
            customHrZones: profileData['custom_hr_zones'] != null
                ? (profileData['custom_hr_zones'] as List)
                    .map((e) => Map<String, int>.from(e as Map))
                    .toList()
                : null,
          );
          _isLoggedIn = true;
          _prefs!.setBool('isLoggedIn', true);
          await _loadAllData();
        }
        notifyListeners();
      }

      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  bool get isAppleSignInAvailable => !kIsWeb && Platform.isIOS;

  /// Cryptographically-strong random nonce in the URL-safe charset Apple expects.
  String _generateNonce([int length = 32]) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Future<AuthResponse?> signInWithApple() async {
    try {
      if (!kIsWeb && !(Platform.isIOS || Platform.isMacOS)) {
        throw 'Sign in with Apple è disponibile solo su iOS, macOS e Web.';
      }

      // Generate a fresh nonce and pass the SHA-256 hash to Apple; Supabase
      // gets the raw nonce and verifies the hashed copy embedded in the id_token.
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'No Identity Token from Apple.';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        // Apple only returns givenName / familyName / email on the FIRST
        // authorization, so fall back to whatever Supabase has on the user.
        final meta = response.user!.userMetadata ?? {};
        final fallbackFirst =
            (meta['given_name'] ?? meta['first_name'] ?? '') as String;
        final fallbackLast =
            (meta['family_name'] ?? meta['last_name'] ?? '') as String;
        final fallbackEmail = response.user!.email ?? '';

        if (profileData == null) {
          _isNewAppleUser = true;
          _userProfile = UserProfile(
            firstName: credential.givenName ??
                (fallbackFirst.isNotEmpty ? fallbackFirst : 'Nuovo'),
            lastName: credential.familyName ??
                (fallbackLast.isNotEmpty ? fallbackLast : 'Utente'),
            email: credential.email ?? fallbackEmail,
            birthDate: '',
            role: 'athlete',
            weight: 0.0,
            height: 0.0,
            maxHr: 0,
            avatarUrl: '',
            unitSystem: 'metric',
            language: 'it',
            notificationsEnabled: true,
            connectedDevices: [],
            oneRepMax: {},
          );
          // Do NOT mark logged in yet — auth_screen will collect missing fields
          // and then call login() to persist the completed profile.
        } else {
          _isNewAppleUser = false;
          _userProfile = UserProfile(
            firstName: profileData['first_name'] ?? '',
            lastName: profileData['last_name'] ?? '',
            email: profileData['email'] ?? '',
            birthDate: profileData['birth_date'] ?? '2000-01-01',
            role: profileData['role'] ?? 'athlete',
            weight: (profileData['weight'] as num?)?.toDouble() ?? 70.0,
            height: (profileData['height'] as num?)?.toDouble() ?? 175.0,
            maxHr: profileData['max_hr'] ?? 190,
            avatarUrl: profileData['avatar_url'] ?? '',
            unitSystem: _prefs!.getString('unitSystem') ?? 'metric',
            language: _prefs!.getString('language') ?? 'it',
            notificationsEnabled:
                _prefs!.getBool('notificationsEnabled') ?? true,
            connectedDevices: [],
            oneRepMax: {},
            teamId: profileData['team_id'],
            hrZoneMode: profileData['hr_zone_mode'] ?? 'standard',
            customHrZones: profileData['custom_hr_zones'] != null
                ? (profileData['custom_hr_zones'] as List)
                    .map((e) => Map<String, int>.from(e as Map))
                    .toList()
                : null,
          );
          _isLoggedIn = true;
          _prefs!.setBool('isLoggedIn', true);
          await _loadAllData();
        }
        notifyListeners();
      }

      return response;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User-driven cancel — surface as a null response so the UI can ignore it.
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      debugPrint('Apple authorization error: ${e.code} – ${e.message}');
      rethrow;
    } on AuthException catch (e) {
      if (e.code == 'provider_disabled') {
        throw 'Accesso con Apple non ancora abilitato. Abilita il provider Apple in Supabase Auth.';
      }
      debugPrint('Supabase Apple auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }

  void updateProfile(UserProfile updatedProfile) {
    _userProfile = updatedProfile;
    _saveUserProfile();
    notifyListeners();
  }

  bool _isValidUuid(String id) {
    final RegExp regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return regex.hasMatch(id);
  }

  // ==== SUPABASE LOADERS ====

  Future<void> _loadUserProfile() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        _userProfile = UserProfile(
          firstName: data['first_name'] ?? 'Utente',
          lastName: data['last_name'] ?? 'User',
          email: data['email'] ?? '',
          birthDate: data['birth_date'] ?? '2000-01-01',
          role: data['role'] ?? 'athlete',
          weight: (data['weight'] as num?)?.toDouble() ?? 70.0,
          height: (data['height'] as num?)?.toDouble() ?? 175.0,
          maxHr: data['max_hr'] ?? 190,
          avatarUrl: data['avatar_url'] ?? '',
          skiClub: data['ski_club'],
          gender: data['gender'],
          skillLevel: data['skill_level'],
          oneRepMax: data['one_rep_max'] != null
              ? Map<String, double>.from(data['one_rep_max']
                  .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
              : null,
          connectedDevices: data['connected_devices'] != null
              ? List<ConnectedDevice>.from(data['connected_devices']
                  .map((x) => ConnectedDevice.fromJson(x)))
              : [],
          unitSystem: _prefs!.getString('unitSystem') ?? 'metric',
          language: _prefs!.getString('language') ?? 'it',
          notificationsEnabled: _prefs!.getBool('notificationsEnabled') ?? true,
          teamId: data['team_id'],
          hrZoneMode: data['hr_zone_mode'] ?? 'standard',
          customHrZones: data['custom_hr_zones'] != null
              ? (data['custom_hr_zones'] as List)
                  .map((e) => Map<String, int>.from(e as Map))
                  .toList()
              : null,
        );
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadSessions() async {
    try {
      final data = await _supabase
          .from('training_sessions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      _sessions = (data as List)
          .map((e) => TrainingSession(
                id: e['id'],
                sportId: e['sport_id'],
                date: e['date'],
                startTime: e['start_time'],
                endTime: e['end_time'],
                duration: e['duration'],
                effort: e['effort'],
                eventId: e['event_id'],
                details: e['details'],
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  Future<void> _loadTeams() async {
    try {
      if (_userProfile?.teamId != null && _userProfile!.teamId!.isNotEmpty) {
        final data = await _supabase
            .from('teams')
            .select()
            .eq('id', _userProfile!.teamId!);
        _teams = (data as List)
            .map((e) => Team(
                  id: e['id'],
                  name: e['name'],
                  members: e['members'] ?? 0,
                  category: e['category'],
                  image: e['image'],
                  inviteCode: e['invite_code'],
                  description: e['description'],
                  isPrivate: e['is_private'],
                ))
            .toList();
      } else {
        _teams = [];
      }
    } catch (e) {
      debugPrint('Error loading teams: $e');
    }
  }

  Future<void> _loadBodyLogs() async {
    try {
      final data = await _supabase
          .from('body_metric_logs')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: true);
      _bodyLogs = (data as List)
          .map((e) => BodyMetricLog(
                id: e['id'],
                date: e['date'],
                type: e['type'],
                value: (e['value'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading body logs: $e');
    }
  }

  Future<void> _loadPrLogs() async {
    try {
      final data = await _supabase
          .from('pr_logs')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: true);
      _prLogs = (data as List)
          .map((e) => PRLog(
                id: e['id'],
                exerciseId: e['exercise_id'],
                date: e['date'],
                weight: (e['weight'] as num).toDouble(),
                note: e['note'],
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading pr logs: $e');
    }
  }

  Future<void> _loadJumpLogs() async {
    try {
      final data = await _supabase
          .from('jump_logs')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: true);
      _jumpLogs = (data as List)
          .map((e) => JumpLog(
                id: e['id'],
                date: e['date'],
                type: e['type'],
                value: (e['value'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading jump logs: $e');
    }
  }

  Future<void> _loadCoachEvents() async {
    try {
      final data = await _supabase
          .from('calendar_events')
          .select()
          .order('date', ascending: true);
      _coachEvents = (data as List)
          .map((e) => CalendarEvent(
                id: e['id'],
                teamId: e['team_id'] ?? '',
                type: e['type'],
                title: e['title'],
                date: e['date'],
                startTime: e['start_time'] ?? '',
                endTime: e['end_time'] ?? '',
                location: e['location'],
                notes: e['notes'],
                sportCategory: e['sport_category'],
                drylandSpecialty: e['dryland_specialty'],
                technicalDetails: e['technical_details'],
                attendees: e['attendees'] != null
                    ? List<Map<String, dynamic>>.from(e['attendees'])
                    : null,
              ))
          .toList();

      if (_userProfile != null && _userProfile!.role == 'athlete') {
        _coachEvents = _coachEvents.where((e) {
          final tIds = e.teamId.split(',').map((id) => id.trim()).toList();
          return tIds.contains(_userProfile!.teamId) ||
              (e.attendees != null &&
                  e.attendees!.any((a) => a['id'] == userId));
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading coach events: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);
      _notifications = (data as List)
          .map((e) => AppNotification(
                id: e['id'],
                title: e['title'],
                message: e['message'],
                timestamp: e['timestamp'],
                type: e['type'],
                isRead: e['is_read'] ?? false,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // ==== SUPABASE SAVERS ====

  Future<String?> uploadProfileImage(File file) async {
    try {
      final fileExt = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      await _supabase.storage.from('avatars').upload(filePath, file);

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  Future<void> _saveUserProfile() async {
    if (_userProfile != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': userId,
          'first_name': _userProfile!.firstName,
          'last_name': _userProfile!.lastName,
          'email': _userProfile!.email,
          'birth_date': _userProfile!.birthDate,
          'role': _userProfile!.role,
          'weight': _userProfile!.weight,
          'height': _userProfile!.height,
          'max_hr': _userProfile!.maxHr,
          'avatar_url': _userProfile!.avatarUrl,
          'ski_club': _userProfile!.skiClub,
          'gender': _userProfile!.gender,
          'skill_level': _userProfile!.skillLevel,
          'one_rep_max': _userProfile!.oneRepMax,
          'connected_devices':
              _userProfile!.connectedDevices.map((e) => e.toJson()).toList(),
          'team_id': _userProfile!.teamId,
          'hr_zone_mode': _userProfile!.hrZoneMode,
          'custom_hr_zones': _userProfile!.customHrZones,
        });

        // Save local settings
        _prefs!.setString('unitSystem', _userProfile!.unitSystem);
        _prefs!.setString('language', _userProfile!.language);
        _prefs!.setBool(
            'notificationsEnabled', _userProfile!.notificationsEnabled);
      } catch (e) {
        debugPrint('Error saving profile: $e');
      }
    }
  }

  // ==== ACTIONS ====

  Future<void> leaveTeam(String teamId) async {
    try {
      // 1. Update user profile team_id to null
      await _supabase
          .from('profiles')
          .update({'team_id': null}).eq('id', userId);
      if (_userProfile != null) {
        _userProfile!.teamId = null;
        await _saveUserProfile();
      }

      // 2. Decrement team members count
      final teamResponse = await _supabase
          .from('teams')
          .select('members')
          .eq('id', teamId)
          .maybeSingle();
      if (teamResponse != null) {
        final currentMembers = teamResponse['members'] ?? 0;
        final newMembers = currentMembers > 0 ? currentMembers - 1 : 0;
        await _supabase
            .from('teams')
            .update({'members': newMembers}).eq('id', teamId);
      }

      // 3. Update local state
      _teams.removeWhere((t) => t.id == teamId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving team: $e');
      rethrow;
    }
  }

  Future<void> removeAthleteFromTeam(String athleteId, String teamId) async {
    try {
      // 1. Update athlete profile team_id to null
      await _supabase
          .from('profiles')
          .update({'team_id': null}).eq('id', athleteId);

      // 2. Decrement team members count
      final teamResponse = await _supabase
          .from('teams')
          .select('members')
          .eq('id', teamId)
          .maybeSingle();
      if (teamResponse != null) {
        final currentMembers = teamResponse['members'] ?? 0;
        final newMembers = currentMembers > 0 ? currentMembers - 1 : 0;
        await _supabase
            .from('teams')
            .update({'members': newMembers}).eq('id', teamId);
      }

      // Update local team count if it exists locally
      final teamIndex = _teams.indexWhere((t) => t.id == teamId);
      if (teamIndex != -1) {
        final currentMembers = _teams[teamIndex].members;
        _teams[teamIndex].members = currentMembers > 0 ? currentMembers - 1 : 0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing athlete from team: $e');
      rethrow;
    }
  }

  void addTeam(Team team) async {
    try {
      final response = await _supabase
          .from('teams')
          .insert({
            'name': team.name,
            'members': team.members,
            'category': team.category,
            'image': team.image,
            'invite_code': team.inviteCode,
            'description': team.description,
            'is_private': team.isPrivate,
          })
          .select()
          .single();

      team.id = response['id'];
      _teams.add(team);

      if (_userProfile != null) {
        _userProfile!.teamId = team.id;
        await _saveUserProfile();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding team: $e');
    }
  }

  void addSession(TrainingSession session) async {
    try {
      if (!_isValidUuid(session.id)) {
        // Insert new
        final response = await _supabase
            .from('training_sessions')
            .insert({
              'user_id': userId,
              'sport_id': session.sportId,
              'date': session.date,
              'start_time': session.startTime,
              'end_time': session.endTime,
              'duration': session.duration,
              'effort': session.effort,
              'event_id': session.eventId,
              'details': session.details,
            })
            .select()
            .single();
        session.id = response['id'];
        _sessions.insert(0, session);
      } else {
        // Update existing
        await _supabase.from('training_sessions').update({
          'sport_id': session.sportId,
          'date': session.date,
          'start_time': session.startTime,
          'end_time': session.endTime,
          'duration': session.duration,
          'effort': session.effort,
          'event_id': session.eventId,
          'details': session.details,
        }).eq('id', session.id);

        final index = _sessions.indexWhere((s) => s.id == session.id);
        if (index >= 0) {
          _sessions[index] = session;
        }
      }
      _sessions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding/updating session: $e');
    }
  }

  void deleteSession(String id) async {
    try {
      await _supabase.from('training_sessions').delete().eq('id', id);
      _sessions.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  /// Load sessions for a specific athlete (used by coaches to view athlete details)
  Future<List<TrainingSession>> loadSessionsForAthlete(String athleteId) async {
    try {
      final data = await _supabase
          .from('training_sessions')
          .select()
          .eq('user_id', athleteId)
          .order('date', ascending: false);
      return (data as List)
          .map((e) => TrainingSession(
                id: e['id'],
                sportId: e['sport_id'],
                date: e['date'],
                startTime: e['start_time'],
                endTime: e['end_time'],
                duration: e['duration'],
                effort: e['effort'],
                eventId: e['event_id'],
                details: e['details'],
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading sessions for athlete $athleteId: $e');
      return [];
    }
  }

  /// Load body metric logs (weight/height/fat) for a specific athlete (coach view)
  Future<List<BodyMetricLog>> loadBodyLogsForAthlete(String athleteId) async {
    try {
      final data = await _supabase
          .from('body_metric_logs')
          .select()
          .eq('user_id', athleteId)
          .order('date', ascending: true);
      return (data as List)
          .map((e) => BodyMetricLog(
                id: e['id'],
                date: e['date'],
                type: e['type'],
                value: (e['value'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading body logs for athlete $athleteId: $e');
      return [];
    }
  }

  /// Load jump logs for a specific athlete (coach view)
  Future<List<JumpLog>> loadJumpLogsForAthlete(String athleteId) async {
    try {
      final data = await _supabase
          .from('jump_logs')
          .select()
          .eq('user_id', athleteId)
          .order('date', ascending: true);
      return (data as List)
          .map((e) => JumpLog(
                id: e['id'],
                date: e['date'],
                type: e['type'],
                value: (e['value'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading jump logs for athlete $athleteId: $e');
      return [];
    }
  }

  /// Load PR logs for a specific athlete (coach view)
  Future<List<PRLog>> loadPRLogsForAthlete(String athleteId) async {
    try {
      final data = await _supabase
          .from('pr_logs')
          .select()
          .eq('user_id', athleteId)
          .order('date', ascending: true);
      return (data as List)
          .map((e) => PRLog(
                id: e['id'],
                exerciseId: e['exercise_id'],
                date: e['date'],
                weight: (e['weight'] as num).toDouble(),
                note: e['note'],
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading PR logs for athlete $athleteId: $e');
      return [];
    }
  }

  /// Load the profile of a specific athlete (used by coaches)
  Future<UserProfile?> loadAthleteProfile(String athleteId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', athleteId)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile(
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        email: data['email'] ?? '',
        birthDate: data['birth_date'] ?? '2000-01-01',
        role: data['role'] ?? 'athlete',
        weight: (data['weight'] as num?)?.toDouble() ?? 70.0,
        height: (data['height'] as num?)?.toDouble() ?? 175.0,
        maxHr: data['max_hr'] ?? 190,
        avatarUrl: data['avatar_url'] ?? '',
        skiClub: data['ski_club'],
        gender: data['gender'],
        skillLevel: data['skill_level'],
        oneRepMax: data['one_rep_max'] != null
            ? Map<String, double>.from(data['one_rep_max']
                .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
            : null,
        connectedDevices: [],
        unitSystem: 'metric',
        language: 'it',
        notificationsEnabled: false,
      );
    } catch (e) {
      debugPrint('Error loading athlete profile $athleteId: $e');
      return null;
    }
  }

  Future<void> syncHealthWorkouts() async {
    if (_userProfile == null) return;

    try {
      final healthSessions =
          await HealthService().fetchRecentWorkouts(userProfile!, days: 7);

      for (var session in healthSessions) {
        // Check if session already exists by external_id
        final existsByExternalId = _sessions.any((s) =>
            s.details != null &&
            s.details!['external_id'] == session.details!['external_id']);

        // Check for time overlap
        bool timeOverlap = false;
        try {
          DateTime newStart =
              DateTime.parse('${session.date}T${session.startTime}:00');
          DateTime newEnd =
              DateTime.parse('${session.date}T${session.endTime}:00');

          for (var existing in _sessions) {
            if (existing.date == session.date) {
              DateTime extStart =
                  DateTime.parse('${existing.date}T${existing.startTime}:00');
              DateTime extEnd =
                  DateTime.parse('${existing.date}T${existing.endTime}:00');

              if (newStart.isBefore(extEnd) && newEnd.isAfter(extStart)) {
                timeOverlap = true;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing dates for overlap check: $e');
        }

        if (!existsByExternalId && !timeOverlap) {
          addSession(session);
        }
      }

      // Sync Health Metrics (HRV, RHR)
      await syncDailyHealthMetrics();
    } catch (e) {
      debugPrint('Error syncing health workouts: $e');
    }
  }

  void addLocalBodyLog(BodyMetricLog log) {
    try {
      final exists = _bodyLogs.indexWhere((l) => l.type == log.type && l.date == log.date);
      if (exists != -1) {
        _bodyLogs[exists] = log;
      } else {
        _bodyLogs.add(log);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding local body log: $e');
    }
  }

  Future<void> syncDailyHealthMetrics() async {
    try {
      final results = await HealthService().syncDailyHealthMetrics(days: 7);

      for (var rhrLog in results['resting_hr']!) {
        final exists = _bodyLogs
            .any((l) => l.type == 'resting_hr' && l.date == rhrLog.date);
        if (!exists) {
          addBodyLog(rhrLog);
        }
      }

      // Local only metrics
      for (var metricKey in ['spo2', 'resp', 'temp']) {
        for (var log in results[metricKey]!) {
          final exists = _bodyLogs.any((l) => l.type == metricKey && l.date == log.date);
          if (!exists) {
            addLocalBodyLog(log);
          }
        }
      }

      // New HRV Engine logic using Native Channel
      final rawRR = await NativeHealthService.getNightlyRRIntervals();
      if (rawRR.isNotEmpty) {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];

        // Fetch historical HRV baselines
        final historyRes = await _supabase
            .from('hrv_baselines')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: true);

        final historicalData = List<Map<String, dynamic>>.from(historyRes);
        String deviceSource =
            Platform.isIOS ? 'Apple Watch' : 'Health Connect Device';

        final hrvResult = HrvEngine.processNightlyHrv(
          rawRRIntervals: rawRR,
          deviceSource: deviceSource,
          historicalData: historicalData,
        );

        if (hrvResult['rmssd'] > 0) {
          // Salva su hrv_baselines
          await _supabase.from('hrv_baselines').upsert({
            'user_id': userId,
            'date': dateStr,
            'rmssd': hrvResult['rmssd'],
            'device_source': hrvResult['device_source'],
            'rolling_7d': hrvResult['rolling_7d'],
            'rolling_30d': hrvResult['rolling_30d'],
            'rolling_180d': hrvResult['rolling_180d'],
            'rolling_365d': hrvResult['rolling_365d'],
            'needs_calibration': hrvResult['needs_calibration'],
          });

          // Aggiungi in bodyLogs per i grafici esistenti
          final exists =
              _bodyLogs.any((l) => l.type == 'hrv' && l.date == dateStr);
          if (!exists) {
            addBodyLog(BodyMetricLog(
                id: 'hrv_$dateStr',
                date: dateStr,
                type: 'hrv',
                value: hrvResult['rmssd']));
          }
        }
      } else {
        // Fallback a SDNN standard se non ci sono raw RR disponibili
        for (var hrvLog in results['hrv']!) {
          final exists =
              _bodyLogs.any((l) => l.type == 'hrv' && l.date == hrvLog.date);
          if (!exists) {
            addBodyLog(hrvLog);
          }
        }
      }

      // Sync Weight
      if (results.containsKey('weight')) {
        for (var weightLog in results['weight']!) {
          final exists = _bodyLogs
              .any((l) => l.type == 'weight' && l.date == weightLog.date);
          if (!exists) {
            addBodyLog(weightLog);
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing health metrics: $e');
    }
  }

  void addBodyLog(BodyMetricLog log) async {
    try {
      final response = await _supabase
          .from('body_metric_logs')
          .insert({
            'user_id': userId,
            'date': log.date,
            'type': log.type,
            'value': log.value,
          })
          .select()
          .single();

      log.id = response['id'];
      _bodyLogs.add(log);
      _bodyLogs.sort((a, b) => a.date.compareTo(b.date));

      if (log.type == 'weight') {
        _userProfile!.weight = log.value;
      } else if (log.type == 'height') {
        _userProfile!.height = log.value;
      }
      _saveUserProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding body log: $e');
    }
  }

  void deleteBodyLog(String id) async {
    try {
      await _supabase.from('body_metric_logs').delete().eq('id', id);
      _bodyLogs.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting body log: $e');
    }
  }

  void addPRLog(PRLog log) async {
    try {
      final response = await _supabase
          .from('pr_logs')
          .insert({
            'user_id': userId,
            'exercise_id': log.exerciseId,
            'date': log.date,
            'weight': log.weight,
            'note': log.note,
          })
          .select()
          .single();

      log.id = response['id'];
      _prLogs.add(log);
      _prLogs.sort((a, b) => a.date.compareTo(b.date));

      // Initialize oneRepMax map if null
      _userProfile!.oneRepMax ??= {};
      final currentMax = _userProfile!.oneRepMax![log.exerciseId] ?? 0.0;
      if (log.weight > currentMax) {
        _userProfile!.oneRepMax![log.exerciseId] = log.weight;
        _saveUserProfile();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding PR log: $e');
    }
  }

  void deletePRLog(String id) async {
    try {
      // Find which exercise this log belongs to before deleting
      final deletedLog = _prLogs.firstWhere((l) => l.id == id,
          orElse: () => PRLog(id: '', exerciseId: '', date: '', weight: 0));
      final exerciseId = deletedLog.exerciseId;

      await _supabase.from('pr_logs').delete().eq('id', id);
      _prLogs.removeWhere((l) => l.id == id);

      // Recalculate max for this exercise from remaining logs
      if (exerciseId.isNotEmpty && _userProfile != null) {
        _userProfile!.oneRepMax ??= {};
        final remaining =
            _prLogs.where((l) => l.exerciseId == exerciseId).toList();
        if (remaining.isEmpty) {
          _userProfile!.oneRepMax!.remove(exerciseId);
        } else {
          final newMax =
              remaining.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
          _userProfile!.oneRepMax![exerciseId] = newMax;
        }
        _saveUserProfile();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting PR log: $e');
    }
  }

  void addJumpLog(JumpLog log) async {
    try {
      final response = await _supabase
          .from('jump_logs')
          .insert({
            'user_id': userId,
            'type': log.type,
            'date': log.date,
            'value': log.value,
          })
          .select()
          .single();

      log.id = response['id'];
      _jumpLogs.add(log);
      _jumpLogs.sort((a, b) => a.date.compareTo(b.date));
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding jump log: $e');
    }
  }

  void deleteJumpLog(String id) async {
    try {
      await _supabase.from('jump_logs').delete().eq('id', id);
      _jumpLogs.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting jump log: $e');
    }
  }

  Future<void> addJumpLogForAthlete(JumpLog log, String athleteId) async {
    try {
      await _supabase.from('jump_logs').insert({
        'user_id': athleteId,
        'type': log.type,
        'date': log.date,
        'value': log.value,
      });
    } catch (e) {
      debugPrint('Error adding jump log for athlete: $e');
      rethrow;
    }
  }

  Future<void> addPRLogForAthlete(PRLog log, String athleteId) async {
    try {
      await _supabase.from('pr_logs').insert({
        'user_id': athleteId,
        'exercise_id': log.exerciseId,
        'date': log.date,
        'weight': log.weight,
        'note': log.note,
      });
      // Update athlete's one_rep_max profile field
      final profileData = await _supabase
          .from('profiles')
          .select('one_rep_max')
          .eq('id', athleteId)
          .maybeSingle();
      if (profileData != null) {
        final currentMaxMap = profileData['one_rep_max'] != null
            ? Map<String, dynamic>.from(profileData['one_rep_max'])
            : <String, dynamic>{};
        final currentMax =
            (currentMaxMap[log.exerciseId] as num?)?.toDouble() ?? 0.0;
        if (log.weight > currentMax) {
          currentMaxMap[log.exerciseId] = log.weight;
          await _supabase
              .from('profiles')
              .update({'one_rep_max': currentMaxMap}).eq('id', athleteId);
        }
      }
    } catch (e) {
      debugPrint('Error adding PR log for athlete: $e');
      rethrow;
    }
  }

  void saveCoachEvent(CalendarEvent event) async {
    try {
      if (!_isValidUuid(event.id)) {
        final response = await _supabase
            .from('calendar_events')
            .insert({
              'team_id': _isValidUuid(event.teamId) ? event.teamId : null,
              'created_by': userId,
              'type': event.type,
              'title': event.title,
              'date': event.date,
              'start_time': event.startTime,
              'end_time': event.endTime,
              'location': event.location,
              'notes': event.notes,
              'sport_category': event.sportCategory,
              'dryland_specialty': event.drylandSpecialty,
              'technical_details': event.technicalDetails,
              'attendees': event.attendees,
            })
            .select()
            .single();
        event.id = response['id'];
        _coachEvents.add(event);
      } else {
        await _supabase.from('calendar_events').update({
          'team_id': _isValidUuid(event.teamId) ? event.teamId : null,
          'type': event.type,
          'title': event.title,
          'date': event.date,
          'start_time': event.startTime,
          'end_time': event.endTime,
          'location': event.location,
          'notes': event.notes,
          'sport_category': event.sportCategory,
          'dryland_specialty': event.drylandSpecialty,
          'technical_details': event.technicalDetails,
          'attendees': event.attendees,
        }).eq('id', event.id);
        final index = _coachEvents.indexWhere((e) => e.id == event.id);
        if (index >= 0) {
          _coachEvents[index] = event;
        }
      }

      // 3. Handle Future Event Notifications
      _handleFutureEventNotifications(event);

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving coach event: $e');
    }
  }

  void deleteCoachEvent(String id) async {
    try {
      await _supabase.from('calendar_events').delete().eq('id', id);
      _coachEvents.removeWhere((e) => e.id == id);

      // Also delete the associated session in current user's list if present
      _sessions.removeWhere((s) => s.eventId == id);

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting coach event: $e');
    }
  }

  void _handleFutureEventNotifications(CalendarEvent event) async {
    final eventDate = DateTime.tryParse(event.date);
    if (eventDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (eventDate.isAfter(today)) {
      final presentAthletes =
          event.attendees?.where((a) => a['isPresent'] == true).toList() ?? [];

      for (var athlete in presentAthletes) {
        try {
          final response = await _supabase
              .from('notifications')
              .insert({
                'user_id': athlete['id'] ??
                    userId, // Notify athlete, fallback to coach
                'title': 'Nuovo Allenamento Pianificato',
                'message':
                    'Sei stato convocato per: ${event.title} il ${event.date} alle ${event.startTime}',
                'timestamp': DateTime.now().toIso8601String(),
                'type': 'training',
                'is_read': false,
              })
              .select()
              .single();

          final notification = AppNotification(
            id: response['id'],
            title: response['title'],
            message: response['message'],
            timestamp: response['timestamp'],
            type: response['type'],
            isRead: response['is_read'] ?? false,
          );
          _notifications.insert(0, notification);
        } catch (e) {
          debugPrint('Error saving notification: $e');
        }
      }
      notifyListeners();
    }
  }

  Future<void> updateAthleteAttendance(
      CalendarEvent event, bool isPresent) async {
    final athleteName =
        '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
            .trim();
    event.attendees ??= [];

    bool found = false;
    for (var a in event.attendees!) {
      if (a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          a['name'] == athleteName) {
        a['isPresent'] = isPresent;
        found = true;
      }
    }

    if (!found) {
      event.attendees!.add({
        'id': userId,
        'name': athleteName,
        'isPresent': isPresent,
        'laps': 6,
      });
    }
    saveCoachEvent(event);
  }

  Future<void> updateAthleteLaps(CalendarEvent event, int laps) async {
    final athleteName =
        '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
            .trim();
    event.attendees ??= [];

    bool found = false;
    for (var a in event.attendees!) {
      if (a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          a['name'] == athleteName) {
        a['laps'] = laps;
        found = true;
      }
    }

    if (!found) {
      event.attendees!.add({
        'id': userId,
        'name': athleteName,
        'isPresent': true,
        'laps': laps,
      });
    }
    saveCoachEvent(event);
  }
}
