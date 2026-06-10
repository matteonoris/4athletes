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
import '../core/dev_flags.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../services/health_service.dart';
import '../services/native_health_service.dart';
import '../services/health_sync_service.dart';
import '../services/training_activity_service.dart';
import '../services/training_reminder_notification_service.dart';
import '../utils/coach_training_utils.dart';
import '../utils/hrv_engine.dart';

class AppState extends ChangeNotifier {
  static const String _healthScoreCachePrefix = 'health_sync_v8_health_90d_';
  static const String _themeModeKey = 'themeMode';

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

  String _themeMode = AppTheme.lightMode;
  String get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == AppTheme.darkMode;

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

  List<WorkoutTemplate> _workoutTemplates = [];
  List<WorkoutTemplate> get workoutTemplates => _workoutTemplates;

  final HealthSyncService _healthSyncService = HealthSyncService();
  final TrainingActivityService _trainingActivityService =
      const TrainingActivityService();

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
  List<Map<String, dynamic>>? get currentLocalSleepHistory =>
      _currentLocalSleepHistory;

  bool _isSyncingHealth = false;
  bool get isSyncingHealth => _isSyncingHealth;

  bool _healthSyncCompleted = false;
  bool get healthSyncCompleted => _healthSyncCompleted;

  String? _healthSyncError;
  String? get healthSyncError => _healthSyncError;

  void _clearCurrentHealthScores() {
    _currentSleepScore = null;
    _currentRecoveryScore = null;
    _currentDailyMetrics = null;
    _currentHistoricalMetrics = null;
    _currentLocalSleepHistory = null;
  }

  bool _loadCachedHealthScores(String cacheKey, String dateKey,
      {required bool syncMissingScoreLogs}) {
    if (_prefs == null || !_prefs!.containsKey(cacheKey)) return false;

    try {
      final cached = jsonDecode(_prefs!.getString(cacheKey)!);
      final sleepScore = (cached['sleepScore'] as num?)?.toDouble();
      if (sleepScore == null) return false;

      _currentSleepScore = sleepScore;
      _currentRecoveryScore = (cached['recoveryScore'] as num?)?.toDouble();
      _currentDailyMetrics =
          Map<String, double>.from(cached['dailyMetrics'] ?? {});
      _currentHistoricalMetrics =
          (cached['historicalMetrics'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, List<double>.from(value)),
      );
      if (cached['localSleepHistory'] != null) {
        _currentLocalSleepHistory =
            List<Map<String, dynamic>>.from(cached['localSleepHistory']);
      }

      if (_currentRecoveryScore == null) {
        _healthSyncError = "CALIBRATION_PHASE";
      }

      if (syncMissingScoreLogs) {
        if (!_bodyLogs
            .any((l) => l.type == 'sleep_score' && l.date == dateKey)) {
          addBodyLog(BodyMetricLog(
            id: 'sleep_score_$dateKey',
            date: dateKey,
            type: 'sleep_score',
            value: _currentSleepScore!,
          ));
        }
        if (_currentRecoveryScore != null &&
            !_bodyLogs
                .any((l) => l.type == 'recovery_score' && l.date == dateKey)) {
          addBodyLog(BodyMetricLog(
            id: 'recovery_score_$dateKey',
            date: dateKey,
            type: 'recovery_score',
            value: _currentRecoveryScore!,
          ));
        }
      }

      _healthSyncCompleted = true;
      _isSyncingHealth = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error loading cached health scores: $e');
      return false;
    }
  }

  Future<void> syncDailyHealthData(DateTime targetDate,
      {bool forceRefresh = false}) async {
    _isSyncingHealth = true;
    _healthSyncCompleted = false;
    _healthSyncError = null;
    _clearCurrentHealthScores();
    notifyListeners();

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime targetDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (targetDay.isAfter(today)) {
      _healthSyncCompleted = true;
      _isSyncingHealth = false;
      notifyListeners();
      return;
    }

    String dateKey = targetDate.toIso8601String().split('T')[0];
    String cacheKey = '$_healthScoreCachePrefix$dateKey';

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

    final shouldReadCache = targetDay.isBefore(today) || !forceRefresh;
    if (shouldReadCache &&
        _loadCachedHealthScores(cacheKey, dateKey,
            syncMissingScoreLogs: targetDay == today)) {
      return;
    }

    if (targetDay.isBefore(today)) {
      _healthSyncCompleted = true;
      _isSyncingHealth = false;
      notifyListeners();
      return;
    }

    // Controlla la cache locale
    if (!forceRefresh && _prefs != null && _prefs!.containsKey(cacheKey)) {
      try {
        final cached = jsonDecode(_prefs!.getString(cacheKey)!);

        // Se il recoveryScore in cache è null, ignoriamo la cache e ricalcoliamo.
        // Questo permette di uscire dalla fase di calibrazione non appena ci sono nuovi dati,
        // o di applicare l'algoritmo corretto se c'era un bug precedentemente cachato.
        if (cached['recoveryScore'] != null) {
          _currentSleepScore = cached['sleepScore'];
          _currentRecoveryScore = cached['recoveryScore'];
          _currentDailyMetrics =
              Map<String, double>.from(cached['dailyMetrics']);
          _currentHistoricalMetrics =
              (cached['historicalMetrics'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<double>.from(value)),
          );
          if (cached['localSleepHistory'] != null) {
            _currentLocalSleepHistory =
                List<Map<String, dynamic>>.from(cached['localSleepHistory']);
          }

          // Ensure today's scores are added to bodyLogs so Analytics screen shows them
          if (_currentSleepScore != null &&
              !_bodyLogs
                  .any((l) => l.type == 'sleep_score' && l.date == dateKey)) {
            addBodyLog(BodyMetricLog(
              id: 'sleep_score_$dateKey',
              date: dateKey,
              type: 'sleep_score',
              value: _currentSleepScore!,
            ));
          }
          if (_currentRecoveryScore != null &&
              !_bodyLogs.any(
                  (l) => l.type == 'recovery_score' && l.date == dateKey)) {
            addBodyLog(BodyMetricLog(
              id: 'recovery_score_$dateKey',
              date: dateKey,
              type: 'recovery_score',
              value: _currentRecoveryScore!,
            ));
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
      final result = await _healthSyncService.fetchAndCalculateScores(
          isLutealPhase, _bodyLogs, targetDate);

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
        final existsSleep =
            _bodyLogs.any((l) => l.type == 'sleep_score' && l.date == dateKey);
        if (!existsSleep && _currentSleepScore != null) {
          final newLog = BodyMetricLog(
            id: 'sleep_score_$dateKey',
            date: dateKey,
            type: 'sleep_score',
            value: _currentSleepScore!,
          );
          addBodyLog(newLog);
        }

        final existsRec = _bodyLogs
            .any((l) => l.type == 'recovery_score' && l.date == dateKey);
        if (!existsRec && _currentRecoveryScore != null) {
          final newLog = BodyMetricLog(
            id: 'recovery_score_$dateKey',
            date: dateKey,
            type: 'recovery_score',
            value: _currentRecoveryScore!,
          );
          addBodyLog(newLog);
        }
      } catch (e) {
        debugPrint('Error syncing sleep/recovery score: $e');
      }

      _healthSyncCompleted = true;

      // Salva in cache
      if (_prefs != null) {
        _prefs!.setString(
            cacheKey,
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
      } else if (errStr.contains('NO_TODAY_SLEEP_DATA')) {
        _clearCurrentHealthScores();
        _healthSyncError = "NO_TODAY_SLEEP_DATA";
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
    _applyThemeMode(_prefs!.getString(_themeModeKey));

    _isLoggedIn = kOnboardingPreviewMode
        ? false
        : (_prefs!.getBool('isLoggedIn') ?? false);

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
    _loadWorkoutTemplates();
  }

  void login(UserProfile profile) async {
    profile.themeMode = _themeMode;
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
    _workoutTemplates.clear();
    await TrainingReminderNotificationService.instance
        .cancelDailyTrainingReminder();
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
            themeMode: _themeMode,
            notificationsEnabled: false,
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
            themeMode: _themeMode,
            notificationsEnabled:
                _prefs!.getBool('notificationsEnabled') ?? false,
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
            themeMode: _themeMode,
            notificationsEnabled: false,
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
            themeMode: _themeMode,
            notificationsEnabled:
                _prefs!.getBool('notificationsEnabled') ?? false,
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
    _applyThemeMode(updatedProfile.themeMode);
    _userProfile = updatedProfile;
    _saveUserProfile();
    TrainingReminderNotificationService.instance.syncForProfile(_userProfile);
    notifyListeners();
  }

  void _applyThemeMode(String? mode) {
    _themeMode = AppTheme.normalizeThemeMode(mode);
    AppTheme.setThemeMode(_themeMode);
    if (_userProfile != null) {
      _userProfile!.themeMode = _themeMode;
    }
  }

  Future<void> setThemeMode(String mode) async {
    final normalized = AppTheme.normalizeThemeMode(mode);
    if (_themeMode == normalized && _userProfile?.themeMode == normalized) {
      return;
    }

    _applyThemeMode(normalized);
    await _prefs?.setString(_themeModeKey, normalized);
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
          themeMode: _themeMode,
          notificationsEnabled:
              _prefs!.getBool('notificationsEnabled') ?? false,
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
                status: e['status'] ?? 'planned',
              ))
          .toList();

      if (_userProfile != null && _userProfile!.role == 'athlete') {
        _coachEvents = _coachEvents.where((e) {
          final tIds = CoachTrainingUtils.teamIdsForEvent(e);
          final athleteName =
              '${_userProfile!.firstName} ${_userProfile!.lastName}'.trim();
          final attendees = e.attendees ?? [];
          final isInvited = attendees.any((a) =>
              a['id'] == userId ||
              a['id'] == _userProfile!.email ||
              (athleteName.isNotEmpty && a['name'] == athleteName));

          // New events are visible only to invited athletes. Keep old events
          // without attendees visible by team for backwards compatibility.
          return isInvited ||
              (attendees.isEmpty && tIds.contains(_userProfile!.teamId));
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

  void _loadWorkoutTemplates() {
    try {
      final raw = _prefs?.getString('workoutTemplates');
      if (raw == null || raw.isEmpty) {
        _workoutTemplates = [];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _workoutTemplates = [];
        return;
      }
      _workoutTemplates = decoded
          .whereType<Map>()
          .map((item) =>
              WorkoutTemplate.fromJson(Map<String, dynamic>.from(item)))
          .where((template) => !template.isArchived)
          .toList();
    } catch (e) {
      debugPrint('Error loading workout templates: $e');
      _workoutTemplates = [];
    }
  }

  Future<void> _saveWorkoutTemplates() async {
    try {
      await _prefs?.setString(
        'workoutTemplates',
        jsonEncode(_workoutTemplates.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving workout templates: $e');
    }
  }

  Future<void> saveWorkoutTemplate(WorkoutTemplate template) async {
    final index = _workoutTemplates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _workoutTemplates[index] = template;
    } else {
      _workoutTemplates.insert(0, template);
    }
    await _saveWorkoutTemplates();
    notifyListeners();
  }

  Future<void> archiveWorkoutTemplate(String templateId) async {
    _workoutTemplates.removeWhere((template) => template.id == templateId);
    await _saveWorkoutTemplates();
    notifyListeners();
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
        _applyThemeMode(_userProfile!.themeMode);
        _prefs!.setString(_themeModeKey, _themeMode);
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

  Future<void> addSession(TrainingSession session) async {
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
      await _syncCoachEventAttendeeLapsFromSession(session);
      await _syncCoachEventDrylandFromSession(session);
      _sessions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding/updating session: $e');
    }
  }

  Future<void> _syncCoachEventAttendeeLapsFromSession(
      TrainingSession session) async {
    if (session.sportId != 'alpine_skiing' ||
        session.eventId == null ||
        session.eventId!.isEmpty ||
        session.details == null) {
      return;
    }

    final details = session.details!;
    final gatedLaps = details['gatedSkiing'] is Map
        ? int.tryParse(details['gatedSkiing']['laps']?.toString() ?? '')
        : null;
    final freeLaps = details['freeSkiing'] is Map
        ? int.tryParse(details['freeSkiing']['laps']?.toString() ?? '')
        : null;

    if (gatedLaps == null && freeLaps == null) return;

    try {
      CalendarEvent? event;
      final localIndex =
          _coachEvents.indexWhere((e) => e.id == session.eventId);
      if (localIndex >= 0) {
        event = _coachEvents[localIndex];
      } else {
        final data = await _supabase
            .from('calendar_events')
            .select()
            .eq('id', session.eventId!)
            .maybeSingle();
        if (data == null) return;
        event = CalendarEvent(
          id: data['id'],
          teamId: data['team_id'] ?? '',
          type: data['type'],
          title: data['title'],
          date: data['date'],
          startTime: data['start_time'] ?? '',
          endTime: data['end_time'] ?? '',
          location: data['location'],
          notes: data['notes'],
          sportCategory: data['sport_category'],
          drylandSpecialty: data['dryland_specialty'],
          technicalDetails: data['technical_details'],
          attendees: data['attendees'] != null
              ? List<Map<String, dynamic>>.from(data['attendees'])
              : null,
          status: data['status'] ?? 'planned',
        );
      }

      final attendeeName =
          '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
              .trim();
      final attendees = event.attendees ?? <Map<String, dynamic>>[];
      final attendeeIndex = attendees.indexWhere((a) =>
          a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          (attendeeName.isNotEmpty && a['name'] == attendeeName));

      if (attendeeIndex < 0) return;

      final specialties = event.technicalDetails?['specialties'];
      final isClEvent = specialties is List &&
          specialties.isNotEmpty &&
          specialties.first.toString() == 'CL';
      final attendee = Map<String, dynamic>.from(attendees[attendeeIndex]);

      if (isClEvent && freeLaps != null) {
        attendee['laps'] = freeLaps;
        attendee['freeLaps'] = freeLaps;
      } else {
        if (gatedLaps != null) attendee['laps'] = gatedLaps;
        if (freeLaps != null) attendee['freeLaps'] = freeLaps;
      }
      attendee['attendanceStatus'] = CoachTrainingUtils.attendancePresent;
      attendee['isPresent'] = true;
      attendee['modifiedByAthlete'] = true;
      attendee['modifiedAt'] = DateTime.now().toIso8601String();

      attendees[attendeeIndex] = attendee;
      event.attendees = attendees;

      await _supabase
          .from('calendar_events')
          .update({'attendees': attendees}).eq('id', event.id);

      if (localIndex >= 0) {
        _coachEvents[localIndex] = event;
      }
    } catch (e) {
      debugPrint('Error syncing event laps from session: $e');
    }
  }

  Future<void> _syncCoachEventDrylandFromSession(
      TrainingSession session) async {
    if (session.sportId == 'alpine_skiing' ||
        session.eventId == null ||
        session.eventId!.isEmpty ||
        session.details == null ||
        session.details!['activityDomain'] != 'dryland') {
      return;
    }

    try {
      CalendarEvent? event;
      final localIndex =
          _coachEvents.indexWhere((e) => e.id == session.eventId);
      if (localIndex >= 0) {
        event = _coachEvents[localIndex];
      } else {
        final data = await _supabase
            .from('calendar_events')
            .select()
            .eq('id', session.eventId!)
            .maybeSingle();
        if (data == null) return;
        event = CalendarEvent(
          id: data['id'],
          teamId: data['team_id'] ?? '',
          type: data['type'],
          title: data['title'],
          date: data['date'],
          startTime: data['start_time'] ?? '',
          endTime: data['end_time'] ?? '',
          location: data['location'],
          notes: data['notes'],
          sportCategory: data['sport_category'],
          drylandSpecialty: data['dryland_specialty'],
          technicalDetails: data['technical_details'],
          attendees: data['attendees'] != null
              ? List<Map<String, dynamic>>.from(data['attendees'])
              : null,
          status: data['status'] ?? 'planned',
        );
      }

      final attendeeName =
          '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
              .trim();
      final attendees = event.attendees ?? <Map<String, dynamic>>[];
      final attendeeIndex = attendees.indexWhere((a) =>
          a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          (attendeeName.isNotEmpty && a['name'] == attendeeName));
      if (attendeeIndex < 0) return;

      final activity = TrainingActivity.fromTrainingSession(
        session,
        athleteId: userId,
        title: session.details!['title']?.toString() ?? event.title,
      ).copyWith(
        source: ActivitySource.athlete,
        status: ActivityStatus.completed,
        athleteModified: true,
        createdByCoach: true,
        linkedCoachEventId: event.id,
      );
      final notes =
          (session.details!['notes'] ?? session.details!['athleteNotes'])
              ?.toString();
      final attendee = _trainingActivityService.withAthleteDrylandActual(
        Map<String, dynamic>.from(attendees[attendeeIndex]),
        actualDrylandDetails: activity.toJson(),
        rpe: session.effort,
        pain: session.details!['pain']?.toString(),
        athleteNotes: notes,
      );
      attendees[attendeeIndex] = attendee;

      await _supabase
          .from('calendar_events')
          .update({'attendees': attendees}).eq('id', event.id);

      event.attendees = attendees;
      if (localIndex >= 0) _coachEvents[localIndex] = event;
    } catch (e) {
      debugPrint('Error syncing dryland event from session: $e');
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

  Future<void> syncHealthWorkouts({int days = 7}) async {
    if (_userProfile == null) return;

    try {
      final healthSessions =
          await HealthService().fetchRecentWorkouts(userProfile!, days: days);

      final processedExternalIds = <String>{};

      for (var session in healthSessions) {
        final extId = session.details?['external_id']?.toString();
        if (extId != null && processedExternalIds.contains(extId)) {
          continue;
        }

        final existingIndex = extId == null
            ? -1
            : _sessions.indexWhere(
                (s) => s.details != null && s.details!['external_id'] == extId);
        final existingByExternalId =
            existingIndex >= 0 ? _sessions[existingIndex] : null;

        if (existingByExternalId != null) {
          if (extId != null) {
            processedExternalIds.add(extId);
          }
          await addSession(
            _mergeHealthImportedSession(existingByExternalId, session),
          );
          continue;
        }

        final sourcePartMatches = _matchingHealthSourcePartSessions(session);
        if (sourcePartMatches.isNotEmpty) {
          if (extId != null) {
            processedExternalIds.add(extId);
          }
          final baseSession = sourcePartMatches.first;
          final duplicateIds = sourcePartMatches
              .skip(1)
              .map((matched) => matched.id)
              .where((id) => id != baseSession.id)
              .toList();
          for (final duplicateId in duplicateIds) {
            await _supabase
                .from('training_sessions')
                .delete()
                .eq('id', duplicateId);
          }
          _sessions.removeWhere((s) => duplicateIds.contains(s.id));
          await addSession(_mergeHealthImportedSession(baseSession, session));
          continue;
        }

        final overlapCandidate = _bestHealthOverlapMergeCandidate(session);
        if (overlapCandidate != null) {
          if (extId != null) {
            processedExternalIds.add(extId);
          }
          await addSession(_mergeHealthImportedSession(
            overlapCandidate,
            session,
          ));
          continue;
        }

        if (extId != null) {
          processedExternalIds.add(extId);
        }
        await addSession(session);
      }

      // Sync Health Metrics (HRV, RHR)
      await syncDailyHealthMetrics();
    } catch (e) {
      debugPrint('Error syncing health workouts: $e');
    }
  }

  TrainingSession? _bestHealthOverlapMergeCandidate(TrainingSession imported) {
    final importedRange = _sessionDateTimeRange(imported);
    if (importedRange == null) return null;

    TrainingSession? best;
    var bestOverlapSeconds = 0;

    for (final existing in _sessions) {
      if (existing.id == imported.id) continue;
      if (!_canMergeHealthImportIntoExisting(existing, imported)) continue;

      final existingRange = _sessionDateTimeRange(existing);
      if (existingRange == null) continue;

      final overlapSeconds = _overlapSeconds(importedRange, existingRange);
      if (overlapSeconds <= 0) continue;

      final importedSeconds =
          importedRange.end.difference(importedRange.start).inSeconds;
      final existingSeconds =
          existingRange.end.difference(existingRange.start).inSeconds;
      final shorterSeconds = min(importedSeconds, existingSeconds);
      final minimumOverlapSeconds =
          min(20 * 60, (shorterSeconds * 0.60).round());

      if (overlapSeconds >= minimumOverlapSeconds &&
          overlapSeconds > bestOverlapSeconds) {
        best = existing;
        bestOverlapSeconds = overlapSeconds;
      }
    }

    return best;
  }

  bool _canMergeHealthImportIntoExisting(
    TrainingSession existing,
    TrainingSession imported,
  ) {
    final details = existing.details ?? const <String, dynamic>{};
    if (details['source'] == 'health_sync') return true;
    if (_hasStructuredDrylandDetails(details)) return false;
    return _sameSportFamily(existing.sportId, imported.sportId);
  }

  bool _hasStructuredDrylandDetails(Map<String, dynamic> details) {
    if (details['activityDomain'] == 'dryland') return true;
    if (details['blocks'] is List) return true;
    if (details['exercises'] is List) return true;
    return false;
  }

  bool _sameSportFamily(String a, String b) {
    String family(String sportId) {
      if (sportId.contains('running') ||
          sportId == 'marathon' ||
          sportId == 'track_field') {
        return 'running';
      }
      if (sportId.contains('cycling') || sportId == 'spinning') {
        return 'cycling';
      }
      if (sportId == 'walking' || sportId == 'hiking') return 'walking';
      if (sportId == 'swimming') return 'swimming';
      if (sportId == 'rowing') return 'rowing';
      if (sportId == 'cross_country_skiing') return 'nordic_ski';
      if (sportId == 'alpine_skiing' || sportId == 'snowboarding') {
        return 'snow';
      }
      return sportId;
    }

    return family(a) == family(b);
  }

  _SessionDateTimeRange? _sessionDateTimeRange(TrainingSession session) {
    try {
      final start = DateTime.parse(
          '${session.date}T${_normalizeSessionClock(session.startTime)}');
      var end = DateTime.parse(
          '${session.date}T${_normalizeSessionClock(session.endTime)}');
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      return _SessionDateTimeRange(start, end);
    } catch (e) {
      debugPrint('Error parsing session range for health import: $e');
      return null;
    }
  }

  String _normalizeSessionClock(String time) {
    final parts = time.trim().split(':');
    if (parts.isEmpty || parts[0].isEmpty) return '00:00:00';
    if (parts.length == 1) return '${parts[0].padLeft(2, '0')}:00:00';
    if (parts.length == 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00';
    }
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:${parts[2].padLeft(2, '0')}';
  }

  int _overlapSeconds(
    _SessionDateTimeRange a,
    _SessionDateTimeRange b,
  ) {
    final start = a.start.isAfter(b.start) ? a.start : b.start;
    final end = a.end.isBefore(b.end) ? a.end : b.end;
    if (!end.isAfter(start)) return 0;
    return end.difference(start).inSeconds;
  }

  List<TrainingSession> _matchingHealthSourcePartSessions(
    TrainingSession imported,
  ) {
    final sourcePartIds = imported.details?['merged_source_workout_ids'];
    if (sourcePartIds is! List || sourcePartIds.isEmpty) return [];

    final ids = sourcePartIds.map((id) => id.toString()).toSet();
    return _sessions.where((session) {
      final details = session.details;
      if (details == null || details['source'] != 'health_sync') return false;
      final externalId = details['external_id']?.toString();
      return externalId != null && ids.contains(externalId);
    }).toList();
  }

  TrainingSession _mergeHealthImportedSession(
    TrainingSession existing,
    TrainingSession imported,
  ) {
    final preservedDetails = Map<String, dynamic>.from(existing.details ?? {});
    const healthManagedKeys = {
      'source',
      'health_import_version',
      'source_name',
      'source_id',
      'external_id',
      'total_duration',
      'total_duration_minutes',
      'total_duration_seconds',
      'active_duration',
      'active_duration_minutes',
      'active_duration_seconds',
      'moving_duration_seconds',
      'duration_source',
      'distance',
      'distance_meters',
      'pace',
      'avg_pace_sec_per_km',
      'speed',
      'avg_speed_kmh',
      'calories',
      'energy_total_kcal',
      'elevation',
      'elevation_meters',
      'elevation_source',
      'avg_hr',
      'avgHeartRate',
      'max_hr',
      'maxHeartRate',
      'hr_reliable',
      'hr_samples',
      'hr_sample_count',
      'hr_coverage_seconds',
      'hr_coverage_minutes',
      'hr_zones',
      'hr_zones_seconds',
      'hr_zone_boundaries',
      'dominant_hr_zone',
      'merged_source_workout_ids',
      'source_part_count',
    };
    preservedDetails.removeWhere((key, _) => healthManagedKeys.contains(key));
    preservedDetails.addAll(imported.details ?? {});

    return TrainingSession(
      id: existing.id,
      sportId: imported.sportId,
      date: imported.date,
      startTime: imported.startTime,
      endTime: imported.endTime,
      duration: imported.duration,
      effort: existing.effort,
      eventId: existing.eventId,
      details: preservedDetails,
    );
  }

  Future<void> refreshAllHealthData(DateTime targetDate) async {
    _isSyncingHealth = true;
    _healthSyncCompleted = false;
    _healthSyncError = null;
    notifyListeners();
    try {
      await syncHealthWorkouts(days: 7);
      await syncDailyHealthData(targetDate, forceRefresh: true);
    } catch (e) {
      debugPrint('Error during manual refresh: $e');
      _healthSyncError = e.toString();
    } finally {
      _isSyncingHealth = false;
      notifyListeners();
    }
  }

  Future<int> clearHealthScoreCacheAndResync(DateTime targetDate) async {
    _isSyncingHealth = true;
    _healthSyncCompleted = false;
    _healthSyncError = null;
    _clearCurrentHealthScores();
    notifyListeners();

    final keys = _prefs
            ?.getKeys()
            .where((key) => key.startsWith(_healthScoreCachePrefix))
            .toList() ??
        <String>[];
    for (final key in keys) {
      await _prefs?.remove(key);
    }

    try {
      await syncHealthWorkouts(days: 7);
      await syncDailyHealthData(targetDate, forceRefresh: true);
      return keys.length;
    } catch (e) {
      debugPrint('Error clearing health cache and resyncing: $e');
      _healthSyncError = e.toString();
      rethrow;
    } finally {
      _isSyncingHealth = false;
      notifyListeners();
    }
  }

  void addLocalBodyLog(BodyMetricLog log) {
    try {
      final exists =
          _bodyLogs.indexWhere((l) => l.type == log.type && l.date == log.date);
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
          final exists =
              _bodyLogs.any((l) => l.type == metricKey && l.date == log.date);
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
    // Aggiornamento ottimistico locale
    final existingIndex =
        _bodyLogs.indexWhere((l) => l.type == log.type && l.date == log.date);
    if (existingIndex >= 0) {
      _bodyLogs[existingIndex].value = log.value;
      log.id = _bodyLogs[existingIndex].id;
    } else {
      _bodyLogs.add(log);
      _bodyLogs.sort((a, b) => a.date.compareTo(b.date));
    }

    if (log.type == 'weight') {
      _userProfile!.weight = log.value;
    } else if (log.type == 'height') {
      _userProfile!.height = log.value;
    }
    _saveUserProfile();
    notifyListeners();

    try {
      final existingData = await _supabase
          .from('body_metric_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('date', log.date)
          .eq('type', log.type)
          .maybeSingle();

      if (existingData != null) {
        await _supabase
            .from('body_metric_logs')
            .update({'value': log.value}).eq('id', existingData['id']);

        final idx = _bodyLogs
            .indexWhere((l) => l.type == log.type && l.date == log.date);
        if (idx >= 0) _bodyLogs[idx].id = existingData['id'];
      } else {
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

        final idx = _bodyLogs
            .indexWhere((l) => l.type == log.type && l.date == log.date);
        if (idx >= 0) _bodyLogs[idx].id = response['id'];
      }
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
      final response = await _supabase
          .from('jump_logs')
          .insert({
            'user_id': athleteId,
            'type': log.type,
            'date': log.date,
            'value': log.value,
          })
          .select()
          .single();
      log.id = response['id'];
    } catch (e) {
      debugPrint('Error adding jump log for athlete: $e');
      rethrow;
    }
  }

  Future<void> deleteJumpLogForAthlete(String id) async {
    try {
      await _supabase.from('jump_logs').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting jump log for athlete: $e');
      rethrow;
    }
  }

  Future<void> addBodyLogForAthlete(BodyMetricLog log, String athleteId) async {
    try {
      final response = await _supabase
          .from('body_metric_logs')
          .insert({
            'user_id': athleteId,
            'type': log.type,
            'date': log.date,
            'value': log.value,
          })
          .select()
          .single();
      log.id = response['id'];
    } catch (e) {
      debugPrint('Error adding body log for athlete: $e');
      rethrow;
    }
  }

  Future<void> deleteBodyLogForAthlete(String id) async {
    try {
      await _supabase.from('body_metric_logs').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting body log for athlete: $e');
      rethrow;
    }
  }

  Future<void> addPRLogForAthlete(PRLog log, String athleteId) async {
    try {
      final response = await _supabase
          .from('pr_logs')
          .insert({
            'user_id': athleteId,
            'exercise_id': log.exerciseId,
            'date': log.date,
            'weight': log.weight,
            'note': log.note,
          })
          .select()
          .single();
      log.id = response['id'];
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

  Future<void> deletePRLogForAthlete(
      String id, String exerciseId, String athleteId) async {
    try {
      await _supabase.from('pr_logs').delete().eq('id', id);

      final data = await _supabase
          .from('pr_logs')
          .select('weight')
          .eq('user_id', athleteId)
          .eq('exercise_id', exerciseId);

      double newMax = 0.0;
      final prLogs = data as List;
      if (prLogs.isNotEmpty) {
        newMax = prLogs
            .map((e) => (e['weight'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
      }

      final profileData = await _supabase
          .from('profiles')
          .select('one_rep_max')
          .eq('id', athleteId)
          .maybeSingle();

      if (profileData != null) {
        final currentMaxMap = profileData['one_rep_max'] != null
            ? Map<String, dynamic>.from(profileData['one_rep_max'])
            : <String, dynamic>{};

        if (newMax > 0) {
          currentMaxMap[exerciseId] = newMax;
        } else {
          currentMaxMap.remove(exerciseId);
        }

        await _supabase
            .from('profiles')
            .update({'one_rep_max': currentMaxMap}).eq('id', athleteId);
      }
    } catch (e) {
      debugPrint('Error deleting PR log for athlete: $e');
      rethrow;
    }
  }

  Future<void> saveCoachEvent(CalendarEvent event) async {
    try {
      final teamIds = CoachTrainingUtils.teamIdsForEvent(event);
      event.teamId = teamIds.isNotEmpty ? teamIds.first : event.teamId;
      event.technicalDetails =
          CoachTrainingUtils.withTeamIds(event.technicalDetails, teamIds);
      event.attendees = (event.attendees ?? [])
          .map((a) => CoachTrainingUtils.normalizeAttendee(a))
          .toList();

      final primaryTeamId = CoachTrainingUtils.primaryTeamIdForEvent(event);
      final payload = {
        'team_id': _isValidUuid(primaryTeamId) ? primaryTeamId : null,
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
        'status': event.status,
      };

      if (!_isValidUuid(event.id)) {
        final response = await _supabase
            .from('calendar_events')
            .insert({...payload, 'created_by': userId})
            .select()
            .single();
        event.id = response['id'];
        _coachEvents.add(event);
      } else {
        await _supabase
            .from('calendar_events')
            .update(payload)
            .eq('id', event.id);
        final index = _coachEvents.indexWhere((e) => e.id == event.id);
        if (index >= 0) {
          _coachEvents[index] = event;
        } else {
          _coachEvents.add(event);
        }
      }

      if (event.status == CoachTrainingUtils.statusCancelled) {
        await _supabase
            .from('training_sessions')
            .delete()
            .eq('event_id', event.id);
        _sessions.removeWhere((s) => s.eventId == event.id);
      } else if (event.status == CoachTrainingUtils.statusCompleted) {
        await _generateSessionsForCompletedEvent(event);
      }

      _handleFutureEventNotifications(event);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving coach event: $e');
    }
  }

  Future<void> _generateSessionsForCompletedEvent(CalendarEvent event) async {
    final presentAthletes = (event.attendees ?? [])
        .where(CoachTrainingUtils.isAttendeePresent)
        .toList();
    final presentIds = <String>{};

    for (final athlete in presentAthletes) {
      final athleteId = athlete['id']?.toString();
      if (athleteId == null || athleteId.isEmpty) continue;

      final resolvedAthleteId = await _resolveAthleteId(athleteId);
      if (resolvedAthleteId == null) continue;
      presentIds.add(resolvedAthleteId);

      final existingSession = await _supabase
          .from('training_sessions')
          .select('id')
          .eq('user_id', resolvedAthleteId)
          .eq('event_id', event.id)
          .maybeSingle();

      final isSkiing = event.sportCategory == 'ski';
      final sessionDetails = isSkiing
          ? CoachTrainingUtils.buildSessionDetailsForAttendee(event, athlete)
          : _trainingActivityService.buildCoachDrylandSessionDetails(
              event,
              athlete,
            );

      final sessionPayload = {
        'user_id': resolvedAthleteId,
        'sport_id': isSkiing
            ? 'alpine_skiing'
            : (event.drylandSpecialty?.isNotEmpty == true
                ? 'dryland_${event.drylandSpecialty!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
                : 'dryland'),
        'date': event.date,
        'start_time': event.startTime,
        'end_time': event.endTime,
        'duration': _calculateEventDuration(event),
        'effort': CoachTrainingUtils.asInt(
          athlete['rpe'],
          fallback: CoachTrainingUtils.asInt(
            event.technicalDetails?['qualityRating'],
            fallback: 5,
          ),
        ),
        'event_id': event.id,
        'details': sessionDetails,
      };

      if (existingSession != null) {
        await _supabase
            .from('training_sessions')
            .update(sessionPayload)
            .eq('id', existingSession['id']);
      } else {
        await _supabase.from('training_sessions').insert(sessionPayload);
      }
    }

    final existing = await _supabase
        .from('training_sessions')
        .select('id,user_id')
        .eq('event_id', event.id);
    for (final row in existing as List) {
      if (!presentIds.contains(row['user_id'])) {
        await _supabase.from('training_sessions').delete().eq('id', row['id']);
      }
    }
  }

  Future<String?> _resolveAthleteId(String athleteId) async {
    if (_isValidUuid(athleteId)) return athleteId;
    try {
      final profileMatch = await _supabase
          .from('profiles')
          .select('id')
          .or('email.eq.$athleteId,first_name.ilike.%$athleteId%')
          .maybeSingle();
      return profileMatch?['id'];
    } catch (_) {
      return null;
    }
  }

  String _calculateEventDuration(CalendarEvent event) {
    try {
      final format = RegExp(r'(\d+):(\d+)');
      final startMatch = format.firstMatch(event.startTime);
      final endMatch = format.firstMatch(event.endTime);
      if (startMatch != null && endMatch != null) {
        final startMin = int.parse(startMatch.group(1)!) * 60 +
            int.parse(startMatch.group(2)!);
        final endMin =
            int.parse(endMatch.group(1)!) * 60 + int.parse(endMatch.group(2)!);
        int diff = endMin - startMin;
        if (diff < 0) diff += 24 * 60;
        final h = diff ~/ 60;
        final m = diff % 60;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
      }
    } catch (_) {}
    return '00:00:00';
  }

  void deleteCoachEvent(String id) async {
    try {
      // 1. Delete associated training sessions
      try {
        await _supabase.from('training_sessions').delete().eq('event_id', id);
      } catch (e) {
        debugPrint('Error deleting training_sessions for event $id: $e');
      }

      // 2. Delete associated notifications (if any)
      try {
        await _supabase.from('notifications').delete().eq('event_id', id);
      } catch (e) {
        debugPrint('Error deleting notifications for event $id: $e');
      }

      // 3. Delete the actual calendar event
      try {
        await _supabase.from('calendar_events').delete().eq('id', id);
      } catch (e) {
        debugPrint('Error deleting calendar_events for event $id: $e');
      }

      // 4. Update local state
      _coachEvents.removeWhere((e) => e.id == id);
      _sessions.removeWhere((s) => s.eventId == id);

      notifyListeners();
    } catch (e) {
      debugPrint('Error in deleteCoachEvent: $e');
    }
  }

  void _handleFutureEventNotifications(CalendarEvent event) async {
    final eventDate = DateTime.tryParse(event.date);
    if (eventDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shouldNotify = event.status == CoachTrainingUtils.statusCancelled ||
        !eventDate.isBefore(today);
    if (!shouldNotify) return;

    final invitedAthletes = event.attendees ?? [];
    for (var athlete in invitedAthletes) {
      try {
        final notificationPayload = {
          'user_id': athlete['id'] ?? userId,
          'title': event.status == CoachTrainingUtils.statusCancelled
              ? 'Allenamento Annullato'
              : 'Nuovo Allenamento Pianificato',
          'message': event.status == CoachTrainingUtils.statusCancelled
              ? 'Allenamento annullato: ${event.title} del ${event.date}'
              : 'Sei stato convocato per: ${event.title} il ${event.date} alle ${event.startTime}',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'training',
          'is_read': false,
        };

        Map<String, dynamic> response;
        try {
          response = await _supabase
              .from('notifications')
              .insert({...notificationPayload, 'event_id': event.id})
              .select()
              .single();
        } catch (_) {
          response = await _supabase
              .from('notifications')
              .insert(notificationPayload)
              .select()
              .single();
        }

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

  Future<void> updateAthleteAttendance(
      CalendarEvent event, bool isPresent) async {
    final status = isPresent
        ? CoachTrainingUtils.attendancePresent
        : CoachTrainingUtils.attendanceAbsent;
    final athleteName =
        '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
            .trim();
    event.attendees ??= [];

    bool found = false;
    for (var a in event.attendees!) {
      if (a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          a['name'] == athleteName) {
        a['attendanceStatus'] = status;
        a['isPresent'] = isPresent;
        a['respondedAt'] = DateTime.now().toIso8601String();
        found = true;
      }
    }

    if (!found) {
      event.attendees!.add({
        'id': userId,
        'name': athleteName,
        'attendanceStatus': status,
        'isPresent': isPresent,
        'laps': 6,
        'freeLaps': 4,
        'respondedAt': DateTime.now().toIso8601String(),
      });
    }
    await saveCoachEvent(event);
  }

  Future<void> updateAthleteLaps(
      CalendarEvent event, int laps, int freeLaps) async {
    await updateAthleteEventDetails(
      event,
      laps: laps,
      freeLaps: freeLaps,
    );
  }

  Future<void> updateAthleteEventDetails(
    CalendarEvent event, {
    int? laps,
    int? freeLaps,
    int? trainingLaps,
    Map<String, int>? trackLaps,
    Map<String, int>? trainingBlockLaps,
    int? rpe,
    String? pain,
    String? chronoNotes,
    String? athleteNotes,
    Map<String, dynamic>? actualDrylandDetails,
  }) async {
    final athleteName =
        '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}'
            .trim();
    event.attendees ??= [];

    bool found = false;
    for (var a in event.attendees!) {
      if (a['id'] == userId ||
          a['id'] == _userProfile?.email ||
          a['name'] == athleteName) {
        if (laps != null) a['laps'] = laps;
        if (freeLaps != null) a['freeLaps'] = freeLaps;
        if (trainingLaps != null) a['trainingLaps'] = trainingLaps;
        if (trackLaps != null) a['trackLaps'] = trackLaps;
        if (trainingBlockLaps != null) {
          a['trainingBlockLaps'] = trainingBlockLaps;
        }
        if (rpe != null) a['rpe'] = rpe;
        if (pain != null) a['pain'] = pain;
        if (chronoNotes != null) a['chronoNotes'] = chronoNotes;
        if (athleteNotes != null) a['athleteNotes'] = athleteNotes;
        if (actualDrylandDetails != null) {
          a['actualDrylandDetails'] = actualDrylandDetails;
        }
        a['attendanceStatus'] = CoachTrainingUtils.attendancePresent;
        a['isPresent'] = true;
        a['modifiedByAthlete'] = true;
        a['modifiedAt'] = DateTime.now().toIso8601String();
        found = true;
      }
    }

    if (!found) {
      event.attendees!.add({
        'id': userId,
        'name': athleteName,
        'attendanceStatus': CoachTrainingUtils.attendancePresent,
        'isPresent': true,
        if (laps != null) 'laps': laps,
        if (freeLaps != null) 'freeLaps': freeLaps,
        if (trainingLaps != null) 'trainingLaps': trainingLaps,
        if (trackLaps != null) 'trackLaps': trackLaps,
        if (trainingBlockLaps != null) 'trainingBlockLaps': trainingBlockLaps,
        if (rpe != null) 'rpe': rpe,
        if (pain != null) 'pain': pain,
        if (chronoNotes != null) 'chronoNotes': chronoNotes,
        if (athleteNotes != null) 'athleteNotes': athleteNotes,
        if (actualDrylandDetails != null)
          'actualDrylandDetails': actualDrylandDetails,
        'modifiedByAthlete': true,
        'modifiedAt': DateTime.now().toIso8601String(),
      });
    }
    await saveCoachEvent(event);
  }
}

class _SessionDateTimeRange {
  final DateTime start;
  final DateTime end;

  const _SessionDateTimeRange(this.start, this.end);
}
