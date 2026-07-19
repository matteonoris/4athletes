import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import 'monthly_team_report_calculator.dart';

class MonthlyTeamReportService {
  final SupabaseClient _supabase;
  final MonthlyTeamReportCalculator _calculator;

  const MonthlyTeamReportService(
    this._supabase, {
    MonthlyTeamReportCalculator calculator =
        const MonthlyTeamReportCalculator(),
  }) : _calculator = calculator;

  Future<MonthlyTeamReport> getMonthlyTeamReport({
    required String teamId,
    required DateTime month,
  }) async {
    final targetMonth = DateTime(month.year, month.month);
    final historyStart = DateTime(month.year, month.month - 6);
    final endExclusive = DateTime(month.year, month.month + 1);

    final teamData =
        await _supabase.from('teams').select().eq('id', teamId).maybeSingle();
    if (teamData == null) {
      throw StateError('Team non trovato o non autorizzato.');
    }
    final team = _teamFromSupabase(Map<String, dynamic>.from(teamData));

    final profilesData = await _supabase
        .from('profiles')
        .select('id, first_name, last_name, avatar_url, skill_level, role')
        .eq('team_id', teamId)
        .eq('role', 'athlete')
        .order('last_name', ascending: true);

    final athleteProfiles = (profilesData as List)
        .whereType<Map>()
        .map((row) => _profileFromSupabase(Map<String, dynamic>.from(row)))
        .toList();
    final athleteIds = athleteProfiles.map((profile) => profile.id).toList();

    final sessions = athleteIds.isEmpty
        ? <TeamReportSession>[]
        : await _loadSessions(
            athleteIds,
            startInclusive: historyStart,
            endExclusive: endExclusive,
          );
    final events = await _loadEvents(
      teamId: teamId,
      startInclusive: historyStart,
      endExclusive: endExclusive,
    );
    final jumpLogs = athleteIds.isEmpty
        ? <TeamReportMetricLog>[]
        : await _loadMetricLogs(
            table: 'jump_logs',
            athleteIds: athleteIds,
            startInclusive: historyStart,
            endExclusive: endExclusive,
          );
    final bodyLogs = athleteIds.isEmpty
        ? <TeamReportMetricLog>[]
        : await _loadMetricLogs(
            table: 'body_metric_logs',
            athleteIds: athleteIds,
            startInclusive: historyStart,
            endExclusive: endExclusive,
          );
    final prLogs = athleteIds.isEmpty
        ? <TeamReportPrLog>[]
        : await _loadPrLogs(
            athleteIds,
            startInclusive: historyStart,
            endExclusive: endExclusive,
          );

    return _calculator.build(
      team: team,
      month: targetMonth,
      athletes: athleteProfiles,
      sessions: sessions,
      events: events,
      jumpLogs: jumpLogs,
      bodyMetricLogs: bodyLogs,
      prLogs: prLogs,
    );
  }

  Future<List<TeamReportSession>> _loadSessions(
    List<String> athleteIds, {
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final data = await _supabase
        .from('training_sessions')
        .select()
        .inFilter('user_id', athleteIds)
        .gte('date', _dateKey(startInclusive))
        .lt('date', _dateKey(endExclusive))
        .order('date', ascending: true);

    return (data as List).whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      return TeamReportSession(
        athleteId: map['user_id']?.toString() ?? '',
        session: TrainingSession(
          id: map['id']?.toString() ?? '',
          sportId: map['sport_id']?.toString() ?? '',
          date: map['date']?.toString() ?? '',
          startTime: map['start_time']?.toString() ?? '',
          endTime: map['end_time']?.toString() ?? '',
          duration: map['duration']?.toString() ?? '0',
          effort: (map['effort'] as num?)?.toInt() ?? 0,
          eventId: map['event_id']?.toString(),
          details: _mapOrNull(map['details']),
        ),
      );
    }).toList();
  }

  Future<List<CalendarEvent>> _loadEvents({
    required String teamId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final data = await _supabase
        .from('calendar_events')
        .select()
        .eq('team_id', teamId)
        .gte('date', _dateKey(startInclusive))
        .lt('date', _dateKey(endExclusive))
        .order('date', ascending: true);

    return (data as List).whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      return CalendarEvent(
        id: map['id']?.toString() ?? '',
        teamId: map['team_id']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        date: map['date']?.toString() ?? '',
        startTime: map['start_time']?.toString() ?? '',
        endTime: map['end_time']?.toString() ?? '',
        location: map['location']?.toString(),
        notes: map['notes']?.toString(),
        sportCategory: map['sport_category']?.toString(),
        drylandSpecialty: map['dryland_specialty']?.toString(),
        technicalDetails: _mapOrNull(map['technical_details']),
        attendees: map['attendees'] is List
            ? (map['attendees'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : null,
        status: map['status']?.toString() ?? 'planned',
      );
    }).toList();
  }

  Future<List<TeamReportMetricLog>> _loadMetricLogs({
    required String table,
    required List<String> athleteIds,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final data = await _supabase
        .from(table)
        .select('user_id, date, type, value')
        .inFilter('user_id', athleteIds)
        .gte('date', _dateKey(startInclusive))
        .lt('date', _dateKey(endExclusive))
        .order('date', ascending: true);

    return (data as List).whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      return TeamReportMetricLog(
        athleteId: map['user_id']?.toString() ?? '',
        date: map['date']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        value: (map['value'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<TeamReportPrLog>> _loadPrLogs(
    List<String> athleteIds, {
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final data = await _supabase
        .from('pr_logs')
        .select('user_id, date, exercise_id, weight')
        .inFilter('user_id', athleteIds)
        .gte('date', _dateKey(startInclusive))
        .lt('date', _dateKey(endExclusive))
        .order('date', ascending: true);

    return (data as List).whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      return TeamReportPrLog(
        athleteId: map['user_id']?.toString() ?? '',
        date: map['date']?.toString() ?? '',
        exerciseId: map['exercise_id']?.toString() ?? '',
        weight: (map['weight'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Team _teamFromSupabase(Map<String, dynamic> map) {
    return Team(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Team',
      members: (map['members'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      inviteCode: map['invite_code']?.toString() ?? '',
      description: map['description']?.toString(),
      isPrivate: map['is_private'] as bool?,
    );
  }

  TeamReportAthleteProfile _profileFromSupabase(Map<String, dynamic> map) {
    return TeamReportAthleteProfile(
      id: map['id']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString() ?? '',
      skillLevel: map['skill_level']?.toString() ?? '',
    );
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
