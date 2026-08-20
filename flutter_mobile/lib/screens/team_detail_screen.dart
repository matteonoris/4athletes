import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/team_leaderboard_calculator.dart';
import '../utils/coach_training_utils.dart';
import 'coach_athlete_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;

  const TeamDetailScreen({super.key, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  TeamLeaderboardTimeRange _timeFilter = TeamLeaderboardTimeRange.last7Days;
  TeamLeaderboardMetric _categoryFilter =
      TeamLeaderboardMetric.hoursOutsideAlpineSki;
  bool _showFilters = true;

  bool _isLoading = true;
  List<Map<String, dynamic>> _rawTeammates = [];
  List<Map<String, dynamic>> _teamCoaches = [];
  List<TeamLeaderboardSession> _rawSessions = [];
  List<CalendarEvent> _completedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final athletesResponse = await supabase
          .from('profiles')
          .select(
              'id, first_name, last_name, email, avatar_url, skill_level, ski_club')
          .eq('team_id', widget.team.id)
          .eq('role', 'athlete')
          .order('last_name', ascending: true);

      final coachesResponse = await supabase
          .from('profiles')
          .select('id, first_name, last_name, avatar_url, ski_club')
          .eq('team_id', widget.team.id)
          .eq('role', 'coach')
          .order('last_name', ascending: true);

      final List<Map<String, dynamic>> athletes =
          List<Map<String, dynamic>>.from(athletesResponse);
      final List<Map<String, dynamic>> coaches =
          List<Map<String, dynamic>>.from(coachesResponse);

      List<TeamLeaderboardSession> sessions = [];
      if (athletes.isNotEmpty) {
        final athleteIds = athletes.map((a) => a['id'] as String).toList();
        final now = DateTime.now();
        final season = TeamLeaderboardPeriod.forRange(
          TeamLeaderboardTimeRange.thisSeason,
          now,
        );
        final last7Days = TeamLeaderboardPeriod.forRange(
          TeamLeaderboardTimeRange.last7Days,
          now,
        );
        final loadStart = last7Days.start.isBefore(season.start)
            ? last7Days.start
            : season.start;
        final seasonStart = _dateKey(loadStart);
        final tomorrow = _dateKey(season.endExclusive);
        final rows =
            await TeamLeaderboardPagination.fetchAll<Map<String, dynamic>>(
          fetchPage: (from, to) async {
            final response = await supabase
                .from('training_sessions')
                .select(
                  'id, user_id, sport_id, date, start_time, end_time, '
                  'duration, effort, event_id, details',
                )
                .inFilter('user_id', athleteIds)
                .gte('date', seasonStart)
                .lt('date', tomorrow)
                .order('date', ascending: true)
                .order('id', ascending: true)
                .range(from, to);
            return List<Map<String, dynamic>>.from(response);
          },
        );
        sessions = rows.map(_leaderboardSessionFromRow).toList();
      }

      final now = DateTime.now();
      final season = TeamLeaderboardPeriod.forRange(
        TeamLeaderboardTimeRange.thisSeason,
        now,
      );
      final last7Days = TeamLeaderboardPeriod.forRange(
        TeamLeaderboardTimeRange.last7Days,
        now,
      );
      final loadStart = last7Days.start.isBefore(season.start)
          ? last7Days.start
          : season.start;
      var completedEvents = <CalendarEvent>[];
      try {
        final eventRows =
            await TeamLeaderboardPagination.fetchAll<Map<String, dynamic>>(
          fetchPage: (from, to) async {
            final response = await supabase
                .from('calendar_events')
                .select(
                  'id, team_id, type, title, date, start_time, end_time, '
                  'location, notes, sport_category, dryland_specialty, '
                  'technical_details, attendees, status',
                )
                .eq('status', 'completed')
                .gte('date', _dateKey(loadStart))
                .lt('date', _dateKey(season.endExclusive))
                .order('date', ascending: true)
                .order('id', ascending: true)
                .range(from, to);
            return List<Map<String, dynamic>>.from(response);
          },
        );
        completedEvents = eventRows
            .map(_calendarEventFromRow)
            .where(
              (event) => CoachTrainingUtils.teamIdsForEvent(event)
                  .contains(widget.team.id),
            )
            .toList();
      } catch (error) {
        debugPrint('Error loading completed events for leaderboard: $error');
      }

      if (!mounted) return;
      setState(() {
        _rawTeammates = athletes;
        _teamCoaches = coaches;
        _rawSessions = sessions;
        _completedEvents = completedEvents;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading leaderboard data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  TeamLeaderboardSession _leaderboardSessionFromRow(
    Map<String, dynamic> row,
  ) {
    final details = row['details'];
    return TeamLeaderboardSession(
      athleteId: row['user_id']?.toString() ?? '',
      session: TrainingSession(
        id: row['id']?.toString() ?? '',
        sportId: row['sport_id']?.toString() ?? '',
        date: row['date']?.toString() ?? '',
        startTime: row['start_time']?.toString() ?? '',
        endTime: row['end_time']?.toString() ?? '',
        duration: row['duration']?.toString() ?? '0',
        effort: row['effort'] is num
            ? (row['effort'] as num).round()
            : int.tryParse(row['effort']?.toString() ?? '') ?? 0,
        eventId: row['event_id']?.toString(),
        details: details is Map
            ? details.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null,
      ),
    );
  }

  CalendarEvent _calendarEventFromRow(Map<String, dynamic> row) {
    return CalendarEvent(
      id: row['id']?.toString() ?? '',
      teamId: row['team_id']?.toString() ?? '',
      type: row['type']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      date: row['date']?.toString() ?? '',
      startTime: row['start_time']?.toString() ?? '',
      endTime: row['end_time']?.toString() ?? '',
      location: row['location']?.toString(),
      notes: row['notes']?.toString(),
      sportCategory: row['sport_category']?.toString(),
      drylandSpecialty: row['dryland_specialty']?.toString(),
      technicalDetails: row['technical_details'] is Map
          ? Map<String, dynamic>.from(row['technical_details'] as Map)
          : null,
      attendees: row['attendees'] is List
          ? (row['attendees'] as List)
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList()
          : null,
      status: row['status']?.toString() ?? '',
    );
  }

  double _getCategoryValue(
    TeamLeaderboardAthleteStats athlete,
    TeamLeaderboardMetric category,
  ) {
    return athlete.valueFor(category);
  }

  String _getCategoryUnit(TeamLeaderboardMetric category) => category.unit;

  IconData _getCategoryIcon(TeamLeaderboardMetric category) {
    switch (category) {
      case TeamLeaderboardMetric.hoursOutsideAlpineSki:
      case TeamLeaderboardMetric.enduranceHours:
        return PhosphorIcons.clock();
      case TeamLeaderboardMetric.zone23Hours:
      case TeamLeaderboardMetric.zone45Hours:
        return PhosphorIcons.heart();
      case TeamLeaderboardMetric.strengthVolumeKg:
        return PhosphorIcons.barbell();
      case TeamLeaderboardMetric.plyometricContacts:
      case TeamLeaderboardMetric.slPolePasses:
        return PhosphorIcons.lightning();
      case TeamLeaderboardMetric.strengthSessions:
      case TeamLeaderboardMetric.enduranceSessions:
        return PhosphorIcons.listChecks();
      case TeamLeaderboardMetric.totalDirectionChanges:
        return PhosphorIcons.waveSine();
      case TeamLeaderboardMetric.gsPolePasses:
        return PhosphorIcons.snowflake();
      default:
        return PhosphorIcons.trendUp();
    }
  }

  String _profileName(Map<String, dynamic> profile, String fallback) {
    final name =
        '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : fallback;
  }

  String _coachSubtitle(Map<String, dynamic> coach) {
    final club = coach['ski_club']?.toString().trim();
    return club != null && club.isNotEmpty ? club : 'Allenatore';
  }

  String _profileInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  Widget _buildProfileAvatar({
    required String name,
    required String avatarUrl,
    required Color backgroundColor,
    required Color textColor,
    double size = 44,
    double radius = 12,
  }) {
    final hasRemoteAvatar =
        avatarUrl.isNotEmpty && avatarUrl.startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        image: hasRemoteAvatar
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      child: hasRemoteAvatar
          ? null
          : Center(
              child: Text(
                _profileInitial(name),
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
    );
  }

  Widget _buildCoachesSection() {
    if (!_isLoading && _teamCoaches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.chalkboardTeacher(),
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ALLENATORI',
                  style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (!_isLoading)
                Text(
                  '${_teamCoaches.length}',
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            ..._teamCoaches.map((coach) {
              final name = _profileName(coach, 'Allenatore');
              final avatar = coach['avatar_url']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: coach == _teamCoaches.last ? 0 : 12,
                ),
                child: Row(
                  children: [
                    _buildProfileAvatar(
                      name: name,
                      avatarUrl: avatar,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
                      textColor: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _coachSubtitle(coach),
                            style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.secondary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Text(
                        'COACH',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  final GlobalKey _shareButtonKey = GlobalKey();

  void _shareCode() {
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    SharePlus.instance.share(
      ShareParams(
        text:
            'Unisciti al mio team su 4Athletes! Usa il codice: ${widget.team.inviteCode}',
        sharePositionOrigin: origin,
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.team.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Codice copiato negli appunti!'),
          behavior: SnackBarBehavior.floating),
    );
  }

  double _getTotalValue(
    Iterable<TeamLeaderboardAthleteStats> athletes,
  ) {
    double total = 0;
    for (final a in athletes) {
      total += _getCategoryValue(a, _categoryFilter);
    }
    return total;
  }

  void _confirmLeaveTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Abbandona Team',
            style: TextStyle(color: AppTheme.textHighEmphasis)),
        content: Text('Sei sicuro di voler abbandonare questo team?',
            style: TextStyle(color: AppTheme.textMediumEmphasis)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('No',
                style: TextStyle(color: AppTheme.textMediumEmphasis)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<AppState>(context, listen: false)
                    .leaveTeam(widget.team.id);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Errore durante l\'uscita dal team')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sì', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveAthlete(
      BuildContext context, String athleteId, String athleteName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Rimuovi Atleta',
            style: TextStyle(color: AppTheme.textHighEmphasis)),
        content: Text(
            'Sei sicuro di voler rimuovere $athleteName da questo team?',
            style: TextStyle(color: AppTheme.textMediumEmphasis)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('No',
                style: TextStyle(color: AppTheme.textMediumEmphasis)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<AppState>(context, listen: false)
                    .removeAthleteFromTeam(athleteId, widget.team.id);
                _loadLeaderboardData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Errore durante la rimozione')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sì', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAthlete =
        Provider.of<AppState>(context).userProfile?.role == 'athlete';
    final isCoach = Provider.of<AppState>(context).userProfile?.role == 'coach';

    final sortedAthletes = const TeamLeaderboardCalculator().calculate(
      athletes: _rawTeammates,
      sessions: _rawSessions,
      completedEvents: _completedEvents,
      timeRange: _timeFilter,
    );
    sortedAthletes.sort((a, b) {
      double valA = _getCategoryValue(a, _categoryFilter);
      double valB = _getCategoryValue(b, _categoryFilter);
      final byValue = valB.compareTo(valA);
      return byValue != 0
          ? byValue
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    double maxValue = sortedAthletes.isEmpty
        ? 1
        : _getCategoryValue(sortedAthletes.first, _categoryFilter);
    if (maxValue <= 0) maxValue = 1;
    final memberCount = _isLoading
        ? widget.team.members
        : sortedAthletes.length + _teamCoaches.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
              color: AppTheme.textHighEmphasis, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(widget.team.name,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textHighEmphasis,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text('$memberCount MEMBERS',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.2)),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isAthlete)
            IconButton(
              icon: Icon(PhosphorIcons.signOut(), color: Colors.redAccent),
              onPressed: () => _confirmLeaveTeam(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // "INVITA MEMBRI" Card
            SliverToBoxAdapter(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: 0.24),
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INVITA MEMBRI',
                              style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _copyCode,
                            child: Row(
                              children: [
                                Text(widget.team.inviteCode,
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: AppTheme.textHighEmphasis)),
                                const SizedBox(width: 8),
                                Icon(PhosphorIcons.copy(),
                                    size: 18,
                                    color: AppTheme.textMediumEmphasis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      key: _shareButtonKey,
                      onPressed: _shareCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('INVIA LINK',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildCoachesSection(),
            ),

            // FILTRI Row 1 (Button, Dropdown, Total)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      icon: Icon(
                          _showFilters
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color:
                              _showFilters ? Colors.white : AppTheme.primary),
                      label: Text('FILTRI',
                          style: TextStyle(
                              color: _showFilters
                                  ? Colors.white
                                  : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _showFilters
                            ? AppTheme.primary
                            : Colors.transparent,
                        side: BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    PopupMenuButton<TeamLeaderboardTimeRange>(
                      onSelected: (value) {
                        setState(() {
                          _timeFilter = value;
                        });
                      },
                      color: AppTheme.card,
                      itemBuilder: (BuildContext context) {
                        return TeamLeaderboardTimeRange.values.map((choice) {
                          return PopupMenuItem<TeamLeaderboardTimeRange>(
                            value: choice,
                            child: Text(
                              choice.label,
                              style: TextStyle(
                                color: _timeFilter == choice
                                    ? AppTheme.primary
                                    : AppTheme.textHighEmphasis,
                                fontWeight: _timeFilter == choice
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.subtleBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.clock(),
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(_timeFilter.label,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.textHighEmphasis)),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down,
                                size: 16, color: AppTheme.textMediumEmphasis),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TOTAL',
                            style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                                _getTotalValue(sortedAthletes)
                                    .toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary)),
                            const SizedBox(width: 2),
                            Text(_getCategoryUnit(_categoryFilter),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            if (_showFilters) ...[
              // I filtri di tempo temporizzati nel popup
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: TeamLeaderboardMetric.values.map((cat) {
                      bool isSelected = _categoryFilter == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _categoryFilter = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.subtleBorder),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(cat),
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textMediumEmphasis),
                                const SizedBox(width: 6),
                                Text(cat.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textMediumEmphasis,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // LEADERBOARD HEADERS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 24, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RANK & ATHLETE',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    Text('VOLUME',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),

            // LEADERBOARD ITEMS
            _isLoading
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    ),
                  )
                : sortedAthletes.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 16),
                          child: Center(
                            child: Text(
                              'Nessun atleta in questo team.',
                              style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final athlete = sortedAthletes[index];
                            double val =
                                _getCategoryValue(athlete, _categoryFilter);
                            bool isFirst = index == 0;

                            return GestureDetector(
                                onTap: () {
                                  if (isCoach) {
                                    HapticFeedback.lightImpact();
                                    final name = athlete.name;
                                    String initial = name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'A';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CoachAthleteDetailScreen(
                                          athleteName: name,
                                          initial: initial,
                                          athleteId: athlete.id,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 12, left: 16, right: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppTheme.subtleBorder),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Highlight on left for #1
                                      if (isFirst) ...[
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                              width: 3,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(16),
                                                        bottomLeft:
                                                            Radius.circular(
                                                                16)),
                                              )),
                                        ),
                                      ],
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            // Rank / Trophy
                                            SizedBox(
                                              width: 28,
                                              child: Center(
                                                child: index == 0
                                                    ? const Icon(
                                                        Icons
                                                            .emoji_events_outlined,
                                                        color:
                                                            Color(0xFFFFD700),
                                                        size: 24)
                                                    : Text('${index + 1}',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: index == 1
                                                                ? AppTheme
                                                                    .textHighEmphasis
                                                                : (index == 2
                                                                    ? const Color(
                                                                        0xFFCD7F32)
                                                                    : AppTheme
                                                                        .textLowEmphasis))),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Avatar
                                            _buildProfileAvatar(
                                              name: athlete.name,
                                              avatarUrl: athlete.avatarUrl,
                                              backgroundColor: AppTheme.surface,
                                              textColor:
                                                  AppTheme.textHighEmphasis,
                                            ),
                                            const SizedBox(width: 16),
                                            // Profile Info and Progress Bar
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(athlete.name,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .textHighEmphasis,
                                                          fontSize: 14)),
                                                  const SizedBox(height: 2),
                                                  Text(athlete.subtitle,
                                                      style: TextStyle(
                                                          color: AppTheme
                                                              .textMediumEmphasis,
                                                          fontSize: 11)),
                                                  const SizedBox(height: 8),
                                                  LayoutBuilder(builder:
                                                      (context, constraints) {
                                                    double percentage =
                                                        val / maxValue;
                                                    if (percentage > 1.0)
                                                      percentage = 1.0;
                                                    return Stack(
                                                      children: [
                                                        Container(
                                                          height: 4,
                                                          width: constraints
                                                              .maxWidth,
                                                          decoration: BoxDecoration(
                                                              color: AppTheme
                                                                  .subtleFill,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2)),
                                                        ),
                                                        Container(
                                                          height: 4,
                                                          width: constraints
                                                                  .maxWidth *
                                                              percentage,
                                                          decoration: BoxDecoration(
                                                              color: isFirst
                                                                  ? AppTheme
                                                                      .primary
                                                                  : AppTheme
                                                                      .textLowEmphasis,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2)),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Value
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.baseline,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              children: [
                                                Text(val.toStringAsFixed(1),
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: isFirst
                                                            ? AppTheme.primary
                                                            : AppTheme
                                                                .textHighEmphasis)),
                                                const SizedBox(width: 2),
                                                Text(
                                                    _getCategoryUnit(
                                                        _categoryFilter),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme
                                                            .textMediumEmphasis)),
                                              ],
                                            ),
                                            if (isCoach) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(
                                                    PhosphorIcons.userMinus(),
                                                    color: Colors.redAccent,
                                                    size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _confirmRemoveAthlete(
                                                  context,
                                                  athlete.id,
                                                  athlete.name,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ));
                          },
                          childCount: sortedAthletes.length,
                        ),
                      ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
