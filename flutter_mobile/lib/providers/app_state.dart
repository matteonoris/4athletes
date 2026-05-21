import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../services/health_service.dart';

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  final _supabase = Supabase.instance.client;
  
  String get userId => _supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isNewGoogleUser = false;
  bool get isNewGoogleUser => _isNewGoogleUser;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  UserProfile? get profile => _userProfile;

  List<TrainingSession> _sessions = [];
  List<TrainingSession> get sessions => _sessions;

  List<Team> _teams = [];
  List<Team> get teams => _teams;

  List<UserProfile> get athletes => []; // Mock athletes

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

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _isLoggedIn = _prefs!.getBool('isLoggedIn') ?? false;

    if (_isLoggedIn) {
      await _loadAllData();
      await syncHealthWorkouts();
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
    await syncHealthWorkouts();
    notifyListeners();
  }

  void logout() async {
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

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        // Fetch or create profile
        final userId = response.user!.id;
        final profileData = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
        
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
            notificationsEnabled: _prefs!.getBool('notificationsEnabled') ?? true,
            connectedDevices: [],
            oneRepMax: {},
            teamId: profileData['team_id'],
          );
          _isLoggedIn = true;
          _prefs!.setBool('isLoggedIn', true);
          await _loadAllData();
          await syncHealthWorkouts();
        }
        notifyListeners();
      }
      
      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  void updateProfile(UserProfile updatedProfile) {
    _userProfile = updatedProfile;
    _saveUserProfile();
    notifyListeners();
  }

  bool _isValidUuid(String id) {
    final RegExp regex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return regex.hasMatch(id);
  }

  // ==== SUPABASE LOADERS ====

  Future<void> _loadUserProfile() async {
    try {
      final data = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (data != null) {
        _userProfile = UserProfile(
          firstName: data['first_name'] ?? 'Mock',
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
          oneRepMax: data['one_rep_max'] != null ? Map<String, double>.from(data['one_rep_max'].map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))) : null,
          connectedDevices: data['connected_devices'] != null ? List<ConnectedDevice>.from(data['connected_devices'].map((x) => ConnectedDevice.fromJson(x))) : [],
          unitSystem: _prefs!.getString('unitSystem') ?? 'metric',
          language: _prefs!.getString('language') ?? 'it',
          notificationsEnabled: _prefs!.getBool('notificationsEnabled') ?? true,
          teamId: data['team_id'],
        );
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadSessions() async {
    try {
      final data = await _supabase.from('training_sessions').select().eq('user_id', userId).order('date', ascending: false);
      _sessions = (data as List).map((e) => TrainingSession(
        id: e['id'],
        sportId: e['sport_id'],
        date: e['date'],
        startTime: e['start_time'],
        endTime: e['end_time'],
        duration: e['duration'],
        effort: e['effort'],
        eventId: e['event_id'],
        details: e['details'],
      )).toList();
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  Future<void> _loadTeams() async {
    try {
      // In a real app we'd query via team_members, but for now we'll load all teams
      final data = await _supabase.from('teams').select();
      _teams = (data as List).map((e) => Team(
        id: e['id'],
        name: e['name'],
        members: e['members'] ?? 0,
        category: e['category'],
        image: e['image'],
        inviteCode: e['invite_code'],
        description: e['description'],
        isPrivate: e['is_private'],
      )).toList();
    } catch (e) {
      debugPrint('Error loading teams: $e');
    }
  }

  Future<void> _loadBodyLogs() async {
    try {
      final data = await _supabase.from('body_metric_logs').select().eq('user_id', userId).order('date', ascending: true);
      _bodyLogs = (data as List).map((e) => BodyMetricLog(
        id: e['id'],
        date: e['date'],
        type: e['type'],
        value: (e['value'] as num).toDouble(),
      )).toList();
    } catch (e) {
      debugPrint('Error loading body logs: $e');
    }
  }

  Future<void> _loadPrLogs() async {
    try {
      final data = await _supabase.from('pr_logs').select().eq('user_id', userId).order('date', ascending: true);
      _prLogs = (data as List).map((e) => PRLog(
        id: e['id'],
        exerciseId: e['exercise_id'],
        date: e['date'],
        weight: (e['weight'] as num).toDouble(),
        note: e['note'],
      )).toList();
    } catch (e) {
      debugPrint('Error loading pr logs: $e');
    }
  }

  Future<void> _loadJumpLogs() async {
    try {
      final data = await _supabase.from('jump_logs').select().eq('user_id', userId).order('date', ascending: true);
      _jumpLogs = (data as List).map((e) => JumpLog(
        id: e['id'],
        date: e['date'],
        type: e['type'],
        value: (e['value'] as num).toDouble(),
      )).toList();
    } catch (e) {
      debugPrint('Error loading jump logs: $e');
    }
  }

  Future<void> _loadCoachEvents() async {
    try {
      final data = await _supabase.from('calendar_events').select().order('date', ascending: true);
      _coachEvents = (data as List).map((e) => CalendarEvent(
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
        attendees: e['attendees'] != null ? List<Map<String, dynamic>>.from(e['attendees']) : null,
      )).toList();
    } catch (e) {
      debugPrint('Error loading coach events: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _supabase.from('notifications').select().eq('user_id', userId).order('timestamp', ascending: false);
      _notifications = (data as List).map((e) => AppNotification(
        id: e['id'],
        title: e['title'],
        message: e['message'],
        timestamp: e['timestamp'],
        type: e['type'],
        isRead: e['is_read'] ?? false,
      )).toList();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // ==== SUPABASE SAVERS ====

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
          'connected_devices': _userProfile!.connectedDevices.map((e) => e.toJson()).toList(),
          'team_id': _userProfile!.teamId,
        });
        
        // Save local settings
        _prefs!.setString('unitSystem', _userProfile!.unitSystem);
        _prefs!.setString('language', _userProfile!.language);
        _prefs!.setBool('notificationsEnabled', _userProfile!.notificationsEnabled);
      } catch (e) {
        debugPrint('Error saving profile: $e');
      }
    }
  }

  // ==== ACTIONS ====

  void addTeam(Team team) async {
    try {
      final response = await _supabase.from('teams').insert({
        'name': team.name,
        'members': team.members,
        'category': team.category,
        'image': team.image,
        'invite_code': team.inviteCode,
        'description': team.description,
        'is_private': team.isPrivate,
      }).select().single();
      
      team.id = response['id'];
      _teams.add(team);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding team: $e');
    }
  }

  void addSession(TrainingSession session) async {
    try {
      if (!_isValidUuid(session.id)) {
        // Insert new
        final response = await _supabase.from('training_sessions').insert({
          'user_id': userId,
          'sport_id': session.sportId,
          'date': session.date,
          'start_time': session.startTime,
          'end_time': session.endTime,
          'duration': session.duration,
          'effort': session.effort,
          'event_id': session.eventId,
          'details': session.details,
        }).select().single();
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

  /// Load sessions for a specific athlete (used by coaches to view athlete details)
  Future<List<TrainingSession>> loadSessionsForAthlete(String athleteId) async {
    try {
      final data = await _supabase
          .from('training_sessions')
          .select()
          .eq('user_id', athleteId)
          .order('date', ascending: false);
      return (data as List).map((e) => TrainingSession(
        id: e['id'],
        sportId: e['sport_id'],
        date: e['date'],
        startTime: e['start_time'],
        endTime: e['end_time'],
        duration: e['duration'],
        effort: e['effort'],
        eventId: e['event_id'],
        details: e['details'],
      )).toList();
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
      return (data as List).map((e) => BodyMetricLog(
        id: e['id'],
        date: e['date'],
        type: e['type'],
        value: (e['value'] as num).toDouble(),
      )).toList();
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
      return (data as List).map((e) => JumpLog(
        id: e['id'],
        date: e['date'],
        type: e['type'],
        value: (e['value'] as num).toDouble(),
      )).toList();
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
      return (data as List).map((e) => PRLog(
        id: e['id'],
        exerciseId: e['exercise_id'],
        date: e['date'],
        weight: (e['weight'] as num).toDouble(),
        note: e['note'],
      )).toList();
    } catch (e) {
      debugPrint('Error loading PR logs for athlete $athleteId: $e');
      return [];
    }
  }

  /// Load the profile of a specific athlete (used by coaches)
  Future<UserProfile?> loadAthleteProfile(String athleteId) async {
    try {
      final data = await _supabase.from('profiles').select().eq('id', athleteId).maybeSingle();
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
            ? Map<String, double>.from(data['one_rep_max'].map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
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
    
    // Check if health connect is enabled in user profile
    final hasHealthConnect = _userProfile!.connectedDevices.any((d) => d.provider == 'health_connect');
    if (!hasHealthConnect) return;

    try {
      final healthSessions = await HealthService().fetchRecentWorkouts(days: 7);
      
      for (var session in healthSessions) {
        // Check if session already exists by external_id
        final exists = _sessions.any((s) => 
            s.details != null && s.details!['external_id'] == session.details!['external_id']);
            
        if (!exists) {
          addSession(session);
        }
      }
    } catch (e) {
      debugPrint('Error syncing health workouts: $e');
    }
  }

  void addBodyLog(BodyMetricLog log) async {
    try {
      final response = await _supabase.from('body_metric_logs').insert({
        'user_id': userId,
        'date': log.date,
        'type': log.type,
        'value': log.value,
      }).select().single();
      
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
      final response = await _supabase.from('pr_logs').insert({
        'user_id': userId,
        'exercise_id': log.exerciseId,
        'date': log.date,
        'weight': log.weight,
        'note': log.note,
      }).select().single();
      
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
      final deletedLog = _prLogs.firstWhere((l) => l.id == id, orElse: () => PRLog(id: '', exerciseId: '', date: '', weight: 0));
      final exerciseId = deletedLog.exerciseId;

      await _supabase.from('pr_logs').delete().eq('id', id);
      _prLogs.removeWhere((l) => l.id == id);

      // Recalculate max for this exercise from remaining logs
      if (exerciseId.isNotEmpty && _userProfile != null) {
        _userProfile!.oneRepMax ??= {};
        final remaining = _prLogs.where((l) => l.exerciseId == exerciseId).toList();
        if (remaining.isEmpty) {
          _userProfile!.oneRepMax!.remove(exerciseId);
        } else {
          final newMax = remaining.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
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
      final response = await _supabase.from('jump_logs').insert({
        'user_id': userId,
        'type': log.type,
        'date': log.date,
        'value': log.value,
      }).select().single();
      
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

  void saveCoachEvent(CalendarEvent event) async {
    try {
      if (!_isValidUuid(event.id)) {
        final response = await _supabase.from('calendar_events').insert({
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
        }).select().single();
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

      // 2. Sync to Athletes (simulate by adding it to CURRENT user's _sessions)
      TrainingSession session = TrainingSession(
        id: '', // Will be generated
        sportId: 'alpine_skiing', 
        date: event.date, 
        startTime: event.startTime,
        endTime: event.endTime,
        duration: '0h 0m', 
        effort: 5, 
        eventId: event.id,
        details: event.technicalDetails,
      );
      addSession(session);

      // 3. Handle Future Event Notifications
      _handleFutureEventNotifications(event);

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving coach event: $e');
    }
  }

  void _handleFutureEventNotifications(CalendarEvent event) async {
    final eventDate = DateTime.tryParse(event.date);
    if (eventDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (eventDate.isAfter(today)) {
      final presentAthletes = event.attendees?.where((a) => a['isPresent'] == true).toList() ?? [];
      
      for (var athlete in presentAthletes) {
        try {
          final response = await _supabase.from('notifications').insert({
            'user_id': userId, // Using mock user for testing
            'title': 'Nuovo Allenamento Pianificato',
            'message': 'Sei stato convocato per: ${event.title} il ${event.date} alle ${event.startTime}',
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'training',
            'is_read': false,
          }).select().single();
          
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
}
