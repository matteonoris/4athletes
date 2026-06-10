import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_mobile/screens/daily_readiness_details_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../utils/health_display_utils.dart';
import '../utils/coach_training_utils.dart';
import '../utils/training_metrics_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_card.dart';

import 'analytics_screen.dart';
import 'health_screen.dart';
import 'activity_select.dart';
import 'teams_screen.dart';
import 'profile_screen.dart';
import 'activity_details_screen.dart';
import 'athlete_event_screen.dart';
import 'body_metrics_screen.dart';
import 'notifications_screen.dart';
import '../widgets/ski_gate_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardView(onProfileTap: () => _onTabTapped(4)),
      const AnalyticsScreen(),
      const HealthScreen(),
      const TeamsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  final VoidCallback onProfileTap;

  const _DashboardView({required this.onProfileTap});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  static const List<String> _homeMotivationPrompts = [
    'Ogni sessione conta.',
    'Oggi si costruisce la prossima performance.',
    'Entra in ritmo e porta qualità.',
    'Piccoli progressi, grandi risultati.',
    'Trasforma l\'energia in allenamento.',
    'Fai parlare i numeri sul campo.',
    'Il prossimo step parte da qui.',
    'Prendi il controllo della tua giornata.',
  ];

  DateTime _currentDate = DateTime.now();
  final int _weightChartDays = 30; // 7, 30, 180
  late String _selectedSeason;

  String _formatDuration(String durationMinutes) {
    return TimeUtils.formatDuration(durationMinutes);
  }

  String _homeMotivationPrompt() {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year)).inDays;
    final index =
        (today.year * 366 + dayOfYear) % _homeMotivationPrompts.length;
    return _homeMotivationPrompts[index];
  }

  @override
  void initState() {
    super.initState();
    _selectedSeason = _getCurrentSeason();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.syncDailyHealthData(_currentDate);
      appState.syncHealthWorkouts();
    });
  }

  String _getCurrentSeason() {
    final now = DateTime.now();
    int startYear = now.month < 5 ? now.year - 1 : now.year;
    return '${startYear.toString().substring(2)}/${(startYear + 1).toString().substring(2)}';
  }

  List<String> _getAvailableSeasons() {
    final now = DateTime.now();
    int currentStartYear = now.month < 5 ? now.year - 1 : now.year;
    return [
      _getCurrentSeason(),
      '${(currentStartYear - 1).toString().substring(2)}/${currentStartYear.toString().substring(2)}',
      '${(currentStartYear - 2).toString().substring(2)}/${(currentStartYear - 1).toString().substring(2)}'
    ];
  }

  bool _isDateInSeason(String dateStr, String seasonLabel) {
    if (dateStr.isEmpty) return false;
    final date = DateTime.parse(dateStr);
    final parts = seasonLabel.split('/');
    if (parts.length != 2) return false;
    int startYear = 2000 + int.parse(parts[0]);
    int endYear = 2000 + int.parse(parts[1]);

    final seasonStart = DateTime(startYear, 5, 1);
    final seasonEnd = DateTime(endYear, 5, 1);

    return date.isAfter(seasonStart.subtract(const Duration(days: 1))) &&
        date.isBefore(seasonEnd);
  }

  bool _isSessionInSeason(TrainingSession session, String seasonLabel) {
    return _isDateInSeason(session.date, seasonLabel);
  }

  void _changeDate(int offset) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: offset));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false)
          .syncDailyHealthData(_currentDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.userProfile;

    if (user == null) return const SizedBox();

    final String dateStr = _currentDate.toIso8601String().split('T')[0];
    final recentSessions =
        appState.sessions.where((s) => s.date == dateStr).toList();
    final dailyCoachEvents = appState.coachEvents.where((e) {
      if (e.date != dateStr) return false;
      final athleteName = '${user.firstName} ${user.lastName}'.trim();
      final attendee = e.attendees?.cast<Map<String, dynamic>?>().firstWhere(
          (a) =>
              a != null &&
              (a['id'] == user.email ||
                  a['id'] == appState.userId ||
                  a['name'] == athleteName),
          orElse: () => null);
      return attendee != null;
    }).toList();

    final cutoff = DateTime.now().subtract(Duration(days: _weightChartDays));
    final filteredWeight = appState.bodyLogs
        .where(
            (l) => l.type == 'weight' && DateTime.parse(l.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final filteredFat = appState.bodyLogs
        .where((l) => l.type == 'fat' && DateTime.parse(l.date).isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final heightLogs =
        appState.bodyLogs.where((l) => l.type == 'height').toList();

    // Stats calculations
    int totalGatedVolume = 0;
    Map<String, int> bySpecialty = {};
    int totalGymMinutes = 0;
    final sessionEventIds = <String>{};

    for (var session in appState.sessions) {
      if (!_isSessionInSeason(session, _selectedSeason)) continue;
      if (session.eventId != null && session.eventId!.isNotEmpty) {
        sessionEventIds.add(session.eventId!);
      }

      if (session.sportId == 'alpine_skiing' && session.details != null) {
        final summary = CoachTrainingUtils.volumeFromDetails(session.details);
        totalGatedVolume += summary.polePasses;
        for (final entry in summary.polePassesBySpecialty.entries) {
          bySpecialty[entry.key] = (bySpecialty[entry.key] ?? 0) + entry.value;
        }
      } else {
        totalGymMinutes += TimeUtils.parseDurationToMinutes(session.duration);
      }
    }

    // Add completed coach events only when the generated session is not loaded.
    for (var event in appState.coachEvents) {
      if (!_isDateInSeason(event.date, _selectedSeason)) continue;
      if (event.sportCategory != 'ski') continue;
      if (event.status != CoachTrainingUtils.statusCompleted) continue;
      if (event.status == CoachTrainingUtils.statusCancelled) continue;
      if (sessionEventIds.contains(event.id)) continue;

      final athleteName = '${user.firstName} ${user.lastName}'.trim();
      final attendee = event.attendees
          ?.cast<Map<String, dynamic>?>()
          .firstWhere(
              (a) =>
                  a != null &&
                  (a['id'] == user.email || a['name'] == athleteName),
              orElse: () => null);

      if (attendee != null && CoachTrainingUtils.isAttendeePresent(attendee)) {
        final summary =
            CoachTrainingUtils.volumeFromEventAttendee(event, attendee);
        totalGatedVolume += summary.polePasses;
        for (final entry in summary.polePassesBySpecialty.entries) {
          bySpecialty[entry.key] = (bySpecialty[entry.key] ?? 0) + entry.value;
        }
      }
    }

    final gymHours = totalGymMinutes ~/ 60;
    final gymMins = totalGymMinutes % 60;
    final extraSkiSummary = TrainingMetricsUtils.extraSkiSummaryFromSessions(
      appState.sessions,
      weekAnchor: _currentDate,
    );
    final weeklyZone23Mins = (extraSkiSummary.weeklyZone23Seconds / 60).round();
    final weeklyZone45Mins = (extraSkiSummary.weeklyZone45Seconds / 60).round();

    // Weight difference calc
    double lastWeight =
        filteredWeight.isNotEmpty ? filteredWeight.last.value : user.weight;
    double prevWeight = filteredWeight.length > 1
        ? filteredWeight[filteredWeight.length - 2].value
        : lastWeight;
    double rawDiff = lastWeight - prevWeight;
    bool isWeightDown = rawDiff < 0;
    bool isWeightSame = rawDiff == 0;
    String displayWeight = lastWeight.toStringAsFixed(1);
    String displayDiffVal = rawDiff.abs().toStringAsFixed(1);
    String diffString = '$displayDiffVal kg';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await appState.refreshAllHealthData(_currentDate);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ciao, ${user.firstName}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _homeMotivationPrompt(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_none,
                                color: AppTheme.textMediumEmphasis),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationsScreen()));
                            },
                          ),
                          if (appState.notifications.any((n) => !n.isRead))
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Apri profilo',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onProfileTap();
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.card,
                            backgroundImage: user.avatarUrl.isNotEmpty
                                ? NetworkImage(user.avatarUrl)
                                : null,
                            child: user.avatarUrl.isEmpty
                                ? Icon(Icons.person,
                                    color: AppTheme.textMediumEmphasis)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Date Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.chevron_left, color: AppTheme.primary),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _changeDate(-1);
                    },
                  ),
                  Text(
                    dateStr == DateTime.now().toIso8601String().split('T')[0]
                        ? 'Oggi'
                        : '${_currentDate.day.toString().padLeft(2, '0')}/${_currentDate.month.toString().padLeft(2, '0')}/${_currentDate.year}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: AppTheme.primary),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _changeDate(1);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildDailyReadiness(appState),

              const SizedBox(height: 8),

              // Season Performance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Andamento Stagionale',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  DropdownButton<String>(
                    value: _selectedSeason,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppTheme.primary),
                    items: _getAvailableSeasons().map((season) {
                      return DropdownMenuItem(
                          value: season, child: Text('Stag. $season'));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSeason = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SkiGateIcon(
                                panelColor: AppTheme.secondary,
                                poleColor: Colors.white70,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text('CAMBI DI DIR.',
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme
                                                      .textMediumEmphasis)),
                                    ),
                                    Text(' (PALI)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                fontSize: 9,
                                                color: AppTheme
                                                    .textMediumEmphasis
                                                    .withValues(alpha: 0.6))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(totalGatedVolume.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (bySpecialty.isNotEmpty)
                            ...bySpecialty.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: e.key == 'SL'
                                                  ? AppTheme.secondary
                                                  : (e.key == 'GS'
                                                      ? Colors.lightBlue
                                                      : Colors.grey),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(e.key,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: AppTheme
                                                          .textMediumEmphasis)),
                                        ],
                                      ),
                                      Text(e.value.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ),
                                ))
                          else
                            Text('Nessuna attività sui pali',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppTheme.textMediumEmphasis,
                                        fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.fitness_center,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('ORE IN PALESTRA',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                AppTheme.textMediumEmphasis)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(text: '$gymHours'),
                                TextSpan(
                                    text: 'h ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color:
                                                AppTheme.textMediumEmphasis)),
                                TextSpan(text: '$gymMins'),
                                TextSpan(
                                    text: 'm',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color:
                                                AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text('Volume Totale',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppTheme.textMediumEmphasis,
                                      fontSize: 10)),
                          if (weeklyZone23Mins > 0 || weeklyZone45Mins > 0) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Z2-Z3 $weeklyZone23Mins m',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Z4-Z5 $weeklyZone45Mins m',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attività (${recentSessions.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (recentSessions.isEmpty && dailyCoachEvents.isEmpty)
                Center(
                  child: Text('Nessuna attività',
                      style: TextStyle(color: AppTheme.textMediumEmphasis)),
                )
              else ...[
                ...dailyCoachEvents.map((event) {
                  final isPast = DateTime.parse(event.date).isBefore(DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day));
                  final athleteName =
                      '${user.firstName} ${user.lastName}'.trim();
                  final attendee = event.attendees
                      ?.cast<Map<String, dynamic>?>()
                      .firstWhere(
                          (a) =>
                              a != null &&
                              (a['id'] == user.email ||
                                  a['name'] == athleteName),
                          orElse: () => null);
                  final isPresent = attendee != null &&
                      CoachTrainingUtils.isAttendeePresent(attendee);
                  final isCancelled =
                      event.status == CoachTrainingUtils.statusCancelled;

                  final matchingSession = recentSessions
                      .cast<TrainingSession?>()
                      .firstWhere((s) => s != null && s.eventId == event.id,
                          orElse: () => null);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (matchingSession != null) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ActivityDetailsScreen(
                                      session: matchingSession,
                                      sportName: event.title)));
                        } else if (isPast) {
                          final dummySession = TrainingSession(
                            id: '',
                            eventId: event.id,
                            date: event.date.split('T')[0],
                            sportId: event.sportCategory == 'ski'
                                ? 'alpine_skiing'
                                : 'athletic_prep',
                            duration: '0:00:00',
                            effort: 0,
                            startTime: event.startTime,
                            endTime: event.endTime,
                            details: event.technicalDetails != null
                                ? Map<String, dynamic>.from(
                                    event.technicalDetails!)
                                : null,
                          );
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ActivityDetailsScreen(
                                      session: dummySession,
                                      sportName: event.title.isNotEmpty
                                          ? event.title
                                          : 'Evento Coach')));
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      AthleteEventScreen(event: event)));
                        }
                      },
                      child: CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1C2530),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                  event.sportCategory == 'ski'
                                      ? Icons.downhill_skiing
                                      : Icons.fitness_center,
                                  color: AppTheme.secondary,
                                  size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          event.title.isNotEmpty
                                              ? event.title
                                              : 'Evento Coach',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.secondary)),
                                      if (isCancelled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppTheme.error
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: const Text('ANNULLATO',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.error,
                                                  fontWeight: FontWeight.bold)),
                                        )
                                      else if (isPast && isPresent)
                                        const Icon(Icons.check_circle,
                                            color: Colors.green, size: 16)
                                      else if (!isPast)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: isPresent
                                                  ? Colors.green
                                                      .withValues(alpha: 0.2)
                                                  : AppTheme.primary
                                                      .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Text(
                                              isPresent
                                                  ? 'CONFERMATO'
                                                  : 'DA CONFERMARE',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isPresent
                                                      ? Colors.green
                                                      : AppTheme.primary,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                          '${event.startTime} - ${event.endTime}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: AppTheme
                                                      .textMediumEmphasis)),
                                      Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text('•',
                                              style: TextStyle(
                                                  color: AppTheme
                                                      .textMediumEmphasis,
                                                  fontSize: 10))),
                                      Text(event.location ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: AppTheme
                                                      .textMediumEmphasis)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                ...recentSessions
                    .where(
                        (s) => !dailyCoachEvents.any((e) => e.id == s.eventId))
                    .map((session) {
                  String sName = session.sportId == 'alpine_skiing'
                      ? 'Alpine Skiing'
                      : session.sportId[0].toUpperCase() +
                          session.sportId.substring(1).replaceAll('_', ' ');
                  IconData sIcon = Icons.fitness_center;
                  if (session.sportId == 'alpine_skiing')
                    sIcon = PhosphorIcons.snowflake();
                  else if (session.sportId.contains('run'))
                    sIcon = Icons.directions_run;
                  else if (session.sportId.contains('cycle'))
                    sIcon = Icons.directions_bike;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityDetailsScreen(
                                session: session, sportName: sName),
                          ),
                        );
                      },
                      child: CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2530),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(sIcon,
                                  color: AppTheme.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        session.date,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                fontSize: 12,
                                                color: AppTheme
                                                    .textMediumEmphasis),
                                      ),
                                    ],
                                  ),
                                  if (session.details != null &&
                                      session.details!['specialties'] != null &&
                                      (session.details!['specialties'] as List)
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 2, bottom: 2),
                                      child: Text(
                                        session.details!['specialties'][0]
                                            .toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color:
                                                    AppTheme.textMediumEmphasis,
                                                fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _formatDuration(session.duration),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppTheme
                                                    .textMediumEmphasis),
                                      ),
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        child: Text('•',
                                            style: TextStyle(
                                                color:
                                                    AppTheme.textMediumEmphasis,
                                                fontSize: 10)),
                                      ),
                                      Text(
                                        'RPE ${session.effort}/10',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppTheme
                                                    .textMediumEmphasis),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 32),

              // Weight Chart
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BodyMetricsScreen(initialMetric: 'weight'),
                  ),
                ),
                child: CustomCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Peso & Massa Grassa',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(displayWeight,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text('kg',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: AppTheme
                                                    .textMediumEmphasis)),
                                  ],
                                ),
                              ],
                            ),
                            if (filteredWeight.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isWeightSame
                                          ? Icons.remove
                                          : (isWeightDown
                                              ? Icons.trending_down
                                              : Icons.trending_up),
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isWeightSame ? 'Stabile' : diffString,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (filteredWeight.isEmpty)
                          Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Nessun dato',
                                      style: TextStyle(
                                          color: AppTheme.textMediumEmphasis))))
                        else
                          Builder(
                            builder: (context) {
                              // Calculate ranges for dual axis scaling
                              double minW = filteredWeight
                                  .map((e) => e.value)
                                  .reduce((a, b) => a < b ? a : b);
                              double maxW = filteredWeight
                                  .map((e) => e.value)
                                  .reduce((a, b) => a > b ? a : b);
                              double minF = filteredFat.isNotEmpty
                                  ? filteredFat
                                      .map((e) => e.value)
                                      .reduce((a, b) => a < b ? a : b)
                                  : 10;
                              double maxF = filteredFat.isNotEmpty
                                  ? filteredFat
                                      .map((e) => e.value)
                                      .reduce((a, b) => a > b ? a : b)
                                  : 25;

                              // Add some padding to ranges
                              minW -= 2;
                              maxW += 2;
                              minF -= 2;
                              maxF += 2;
                              final chartStart = DateTime(
                                cutoff.year,
                                cutoff.month,
                                cutoff.day,
                              );
                              final chartEnd = DateTime.now();
                              final chartDays = math.max(
                                1,
                                DateTime(
                                  chartEnd.year,
                                  chartEnd.month,
                                  chartEnd.day,
                                ).difference(chartStart).inDays,
                              );
                              double xForDate(String date) {
                                final parsed = DateTime.tryParse(date);
                                if (parsed == null) return 0;
                                return DateTime(
                                  parsed.year,
                                  parsed.month,
                                  parsed.day,
                                )
                                    .difference(chartStart)
                                    .inDays
                                    .clamp(0, chartDays)
                                    .toDouble();
                              }

                              // Helper to scale Fat to Weight range
                              double scaleFat(double fat) {
                                if (maxF == minF) return (maxW + minW) / 2;
                                return ((fat - minF) / (maxF - minF)) *
                                        (maxW - minW) +
                                    minW;
                              }

                              return SizedBox(
                                height: 180,
                                child: LineChart(
                                  LineChartData(
                                    minX: 0,
                                    maxX: chartDays.toDouble(),
                                    minY: minW,
                                    maxY: maxW,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      verticalInterval:
                                          filteredWeight.length > 7 ? 7 : 1,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                              strokeWidth: 1),
                                      getDrawingVerticalLine: (value) => FlLine(
                                          color: Colors.white
                                              .withValues(alpha: 0.05),
                                          strokeWidth: 1,
                                          dashArray: [5, 5]),
                                    ),
                                    titlesData: FlTitlesData(
                                      topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: chartDays / 2,
                                          getTitlesWidget: (value, meta) {
                                            final isEdgeOrMiddle = value == 0 ||
                                                (value - chartDays / 2).abs() <
                                                    0.01 ||
                                                (value - chartDays).abs() <
                                                    0.01;
                                            if (!isEdgeOrMiddle) {
                                              return const SizedBox.shrink();
                                            }

                                            final d = chartStart.add(
                                                Duration(days: value.round()));
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 10),
                                              child: Text(
                                                DateFormat('E d', 'it')
                                                    .format(d),
                                                style: TextStyle(
                                                    color: AppTheme
                                                        .textMediumEmphasis,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        axisNameWidget: const Text('% Fat',
                                            style: TextStyle(
                                                color: AppTheme.secondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          getTitlesWidget: (value, meta) {
                                            // Inverse scale to show % Fat labels
                                            double fatVal = ((value - minW) /
                                                        (maxW - minW)) *
                                                    (maxF - minF) +
                                                minF;
                                            return Text(
                                                fatVal.toStringAsFixed(0),
                                                style: const TextStyle(
                                                    color: AppTheme.secondary,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold));
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        axisNameWidget: const Text('kg Weight',
                                            style: TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                                value.toStringAsFixed(0),
                                                style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold));
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      // Weight Line (Primary Axis)
                                      LineChartBarData(
                                        spots: filteredWeight
                                            .map((log) => FlSpot(
                                                xForDate(log.date), log.value))
                                            .toList(),
                                        isCurved: true,
                                        color: AppTheme.primary,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) =>
                                                  FlDotCirclePainter(
                                                      radius: 3,
                                                      color: AppTheme.primary,
                                                      strokeWidth: 1,
                                                      strokeColor:
                                                          AppTheme.background),
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primary
                                                  .withValues(alpha: 0.2),
                                              Colors.transparent
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      // Fat Line (Scaled to Weight Axis)
                                      if (filteredFat.isNotEmpty)
                                        LineChartBarData(
                                          spots: filteredFat
                                              .map((log) => FlSpot(
                                                  xForDate(log.date),
                                                  scaleFat(log.value)))
                                              .toList(),
                                          isCurved: true,
                                          color: AppTheme.secondary,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent,
                                                    barData, index) =>
                                                FlDotCirclePainter(
                                                    radius: 3,
                                                    color: AppTheme.secondary,
                                                    strokeWidth: 1,
                                                    strokeColor:
                                                        AppTheme.background),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Height Chart
              if (heightLogs.isNotEmpty && user.age < 18)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const BodyMetricsScreen(initialMetric: 'height'),
                    ),
                  ),
                  child: CustomCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Altezza Trend',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                          heightLogs.last.value
                                              .toStringAsFixed(0),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Text('cm',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: AppTheme
                                                      .textMediumEmphasis)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.trending_up,
                                        size: 16, color: AppTheme.secondary),
                                    const SizedBox(width: 4),
                                    const Text('Growing',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.secondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 80,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      strokeWidth: 1),
                                ),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: (heightLogs.length > 2)
                                          ? (heightLogs.length - 1) / 2
                                          : 1.0,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.round();
                                        if (value != idx.toDouble() ||
                                            idx < 0 ||
                                            idx >= heightLogs.length)
                                          return const SizedBox.shrink();

                                        final d = DateTime.tryParse(
                                            heightLogs[idx].date);
                                        if (d == null)
                                          return const SizedBox.shrink();
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(
                                            DateFormat('E d', 'it').format(d),
                                            style: TextStyle(
                                                color:
                                                    AppTheme.textMediumEmphasis,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (value, meta) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: Text(value.toStringAsFixed(0),
                                            style: TextStyle(
                                                color:
                                                    AppTheme.textMediumEmphasis,
                                                fontSize: 11)),
                                      ),
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: heightLogs
                                        .asMap()
                                        .entries
                                        .map((e) => FlSpot(
                                            e.key.toDouble(), e.value.value))
                                        .toList(),
                                    isCurved: true,
                                    color: const Color(0xFF9462E5),
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF9462E5)
                                              .withValues(alpha: 0.3),
                                          Colors.transparent
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              const SizedBox(height: 64), // extra padding for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ActivitySelectScreen()),
          );
        },
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.add, color: AppTheme.background, size: 32),
      ),
    );
  }

  Widget _buildDailyReadiness(AppState appState) {
    if (appState.isSyncingHealth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Readiness',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMediumEmphasis)),
          const SizedBox(height: 12),
          CustomCard(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingSyncIcon(),
                  SizedBox(height: 20),
                  Text(
                    'Sincronizzazione in Corso',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighEmphasis,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sincronizzazione degli allenamenti e analisi dei dati biologici da Health Connect / Apple Health. Ricalcolo dei punteggi in corso...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    if (appState.healthSyncError == "NO_TODAY_SLEEP_DATA") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Readiness',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMediumEmphasis)),
          const SizedBox(height: 12),
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.primary, size: 36),
                  const SizedBox(height: 16),
                  const Text(
                    'I dati per oggi non sono presenti',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '4Athletes non trova in Health Connect o Apple Health i dati del sonno necessari per calcolare sonno e recupero di oggi. Controlla che l\'app di terzi li abbia esportati e che i permessi siano attivi, poi riprova.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Riprova Sincronizzazione'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      appState.refreshAllHealthData(_currentDate);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Controlla permessi'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      openAppSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    bool isCalibration = appState.healthSyncError == "CALIBRATION_PHASE";
    if (appState.healthSyncCompleted &&
        (appState.currentRecoveryScore != null || isCalibration)) {
      const sleepScoreColor = Color(0xFF2438A6);
      final recoveryScoreColor = isCalibration
          ? Colors.grey[700]!
          : _recoveryScoreColor(appState.currentRecoveryScore);
      final readiness = isCalibration
          ? 'Readiness: ${readinessStatus(null)}'
          : 'Readiness: ${readinessStatus(appState.currentRecoveryScore)}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Readiness',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMediumEmphasis)),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 4),
                  if (isCalibration)
                    const Text('In Calibrazione',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold))
                  else
                    const Text('Sincronizzato',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyReadinessDetailsScreen(
                            title: 'Sleep Score',
                            score: appState.currentSleepScore!,
                            dailyMetrics: appState.currentDailyMetrics ?? {},
                            historicalMetrics:
                                appState.currentHistoricalMetrics ?? {},
                          ),
                        ),
                      );
                    },
                    child: CustomCard(
                      padding: const EdgeInsets.all(16),
                      height: 194,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.nightlight_round,
                                  color: Colors.indigoAccent, size: 16),
                              const SizedBox(width: 8),
                              Text('Sleep',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textMediumEmphasis)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ScoreRing(
                            value: appState.currentSleepScore! / 100.0,
                            label:
                                appState.currentSleepScore!.toStringAsFixed(0),
                            color: sleepScoreColor,
                            secondaryColor: const Color(0xFF6C7BFF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyReadinessDetailsScreen(
                            title: 'Recovery',
                            score: appState.currentRecoveryScore,
                            dailyMetrics: appState.currentDailyMetrics ?? {},
                            historicalMetrics:
                                appState.currentHistoricalMetrics ?? {},
                          ),
                        ),
                      );
                    },
                    child: CustomCard(
                      padding: const EdgeInsets.all(16),
                      height: 194,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.battery_charging_full,
                                  color: recoveryScoreColor, size: 16),
                              const SizedBox(width: 8),
                              Text('Recovery',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textMediumEmphasis)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ScoreRing(
                            value: isCalibration
                                ? 1.0
                                : appState.currentRecoveryScore! / 100.0,
                            label: isCalibration
                                ? '--'
                                : appState.currentRecoveryScore!
                                    .toStringAsFixed(0),
                            color: recoveryScoreColor,
                            secondaryColor: isCalibration
                                ? Colors.grey[500]!
                                : _recoveryScoreHighlight(
                                    appState.currentRecoveryScore,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            readiness,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    if (appState.healthSyncError != null &&
        appState.healthSyncError != "CALIBRATION_PHASE") {
      if (appState.healthSyncError == "HEALTH_CONNECT_NOT_INSTALLED") {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Readiness',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMediumEmphasis)),
            const SizedBox(height: 12),
            CustomCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 32),
                    const SizedBox(height: 16),
                    const Text('Health Connect Mancante',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        'Per sincronizzare i tuoi dati salute su Android, è necessario installare l\'app ufficiale di Google.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMediumEmphasis)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Scarica dal Play Store'),
                      onPressed: () async {
                        final url = Uri.parse(
                            'market://details?id=com.google.android.apps.healthdata');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Readiness',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMediumEmphasis)),
          const SizedBox(height: 12),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Errore: \${appState.healthSyncError}',
                    style:
                        const TextStyle(color: AppTheme.error, fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    openAppSettings();
                  },
                  icon: const Icon(Icons.settings,
                      color: AppTheme.primary, size: 16),
                  label: const Text('Apri Impostazioni Permessi',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Readiness',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMediumEmphasis)),
        const SizedBox(height: 12),
        CustomCard(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Nessun dato disponibile per questa data.',
                style: TextStyle(color: AppTheme.textMediumEmphasis)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _recoveryScoreColor(double? score) {
    if (score == null) return Colors.grey[700]!;
    if (score <= 33) return const Color(0xFFFF5252);
    if (score <= 66) return const Color(0xFFFFC857);
    return const Color(0xFF22C55E);
  }

  Color _recoveryScoreHighlight(double? score) {
    if (score == null) return Colors.grey[500]!;
    if (score <= 33) return const Color(0xFFFF8A80);
    if (score <= 66) return const Color(0xFFFFE082);
    return const Color(0xFF86EFAC);
  }
}

class _ScoreRing extends StatelessWidget {
  final double value;
  final String label;
  final Color color;
  final Color secondaryColor;

  const _ScoreRing({
    required this.value,
    required this.label,
    required this.color,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          value: value.clamp(0.0, 1.0).toDouble(),
          color: color,
          secondaryColor: secondaryColor,
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: secondaryColor,
                ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color secondaryColor;

  const _ScoreRingPainter({
    required this.value,
    required this.color,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 10) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * value;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surface;
    canvas.drawCircle(center, radius, trackPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = color.withValues(alpha: 0.28);
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + math.pi * 2,
        colors: [secondaryColor, color, secondaryColor],
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    final capAngle = startAngle + sweepAngle;
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(capAngle) * radius,
        center.dy + math.sin(capAngle) * radius,
      ),
      4,
      Paint()
        ..style = PaintingStyle.fill
        ..color = secondaryColor,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _PulsingSyncIcon extends StatefulWidget {
  const _PulsingSyncIcon();

  @override
  State<_PulsingSyncIcon> createState() => _PulsingSyncIconState();
}

class _PulsingSyncIconState extends State<_PulsingSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.1415926535,
              child: const Icon(
                Icons.sync,
                color: AppTheme.primary,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}
