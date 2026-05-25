import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_card.dart';

import 'analytics_screen.dart';
import 'activity_select.dart';
import 'teams_screen.dart';
import 'profile_screen.dart';
// removed activity_details_screen.dart
import 'add_training_screen.dart';
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

  final List<Widget> _pages = [
    const _DashboardView(),
    const AnalyticsScreen(),
    const TeamsScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  DateTime _currentDate = DateTime.now();
  final int _weightChartDays = 30; // 7, 30, 180
  late String _selectedSeason;

  String _formatDuration(String durationMinutes) {
    if (durationMinutes.contains('h')) return durationMinutes; 
    final mins = int.tryParse(durationMinutes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (mins == 0) return durationMinutes; 
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  void initState() {
    super.initState();
    _selectedSeason = _getCurrentSeason();
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
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.userProfile;

    if (user == null) return const SizedBox();

    final String dateStr = _currentDate.toIso8601String().split('T')[0];
    final recentSessions =
        appState.sessions.where((s) => s.date == dateStr).toList();
    final dailyCoachEvents =
        appState.coachEvents.where((e) => e.date == dateStr).toList();

    final cutoff = DateTime.now().subtract(Duration(days: _weightChartDays));
    final filteredWeight = appState.bodyLogs
        .where(
            (l) => l.type == 'weight' && DateTime.parse(l.date).isAfter(cutoff))
        .toList();
    final filteredFat = appState.bodyLogs
        .where((l) => l.type == 'fat' && DateTime.parse(l.date).isAfter(cutoff))
        .toList();
    final heightLogs =
        appState.bodyLogs.where((l) => l.type == 'height').toList();

    // Stats calculations to match React
    int totalGatedVolume = 0;
    Map<String, int> bySpecialty = {};
    int totalGymMinutes = 0;

    for (var session in appState.sessions) {
      if (!_isSessionInSeason(session, _selectedSeason)) continue;

      if (session.sportId == 'alpine_skiing' && session.details != null) {
        final details = session.details!;
        final gatedStr = details['gatedSkiing'];
        if (gatedStr is Map<String, dynamic>) {
          final changes =
              int.tryParse(gatedStr['changes']?.toString() ?? '0') ?? 0;
          final laps = int.tryParse(gatedStr['laps']?.toString() ?? '0') ?? 0;
          final vol = changes * laps;
          if (vol > 0) {
            totalGatedVolume += vol;
            final specialties = details['specialties'] as List<dynamic>?;
            String specName = (specialties != null && specialties.isNotEmpty)
                ? specialties[0].toString()
                : 'Mixed';
            if (specName != 'Mixed') {
              if (specName.contains('SL') || specName.toLowerCase().contains('slalom')) specName = 'SL';
              else if (specName.contains('GS') || specName.toLowerCase().contains('gigante')) specName = 'GS';
              else if (specName.contains('SG') || specName.toLowerCase().contains('super')) specName = 'SG';
              else if (specName.contains('DH') || specName.toLowerCase().contains('discesa')) specName = 'DH';
              else if (specName.contains('CL') || specName.toLowerCase().contains('libero')) specName = 'CL';
            }
            bySpecialty[specName] = (bySpecialty[specName] ?? 0) + vol;
          }
        }
      } else {
        // Duration can be stored as plain integer minutes (from _calculateDuration)
        // or in legacy format "Xh Ym"
        final durStr = session.duration.trim();
        final plainMinutes = int.tryParse(durStr);
        if (plainMinutes != null) {
          totalGymMinutes += plainMinutes;
        } else {
          final durLower = durStr.toLowerCase();
          int hours = 0;
          int mins = 0;
          final hMatch = RegExp(r'(\d+)h').firstMatch(durLower);
          final mMatch = RegExp(r'(\d+)m').firstMatch(durLower);
          if (hMatch != null) hours = int.parse(hMatch.group(1)!);
          if (mMatch != null) mins = int.parse(mMatch.group(1)!);
          totalGymMinutes += (hours * 60) + mins;
        }
      }
    }

    // Add coach events to volume calculation
    for (var event in appState.coachEvents) {
      if (!_isDateInSeason(event.date, _selectedSeason)) continue;
      if (event.sportCategory != 'ski') continue;
      
      final athleteName = '${user.firstName} ${user.lastName}'.trim();
      final attendee = event.attendees?.cast<Map<String,dynamic>?>().firstWhere(
        (a) => a != null && (a['id'] == user.email || a['name'] == athleteName),
        orElse: () => null
      );
      
      if (attendee != null && attendee['isPresent'] == true) {
        final tech = event.technicalDetails;
        if (tech != null && tech['gatedSkiing'] != null) {
          final changes = int.tryParse(tech['gatedSkiing']['changes']?.toString() ?? '0') ?? 0;
          final laps = int.tryParse(attendee['laps']?.toString() ?? tech['gatedSkiing']['laps']?.toString() ?? '0') ?? 0;
          final vol = changes * laps;
          if (vol > 0) {
            totalGatedVolume += vol;
            final specialties = tech['specialties'] as List<dynamic>?;
            String specName = (specialties != null && specialties.isNotEmpty)
                ? specialties[0].toString()
                : 'Mixed';
            if (specName != 'Mixed') {
              if (specName.contains('SL') || specName.toLowerCase().contains('slalom')) specName = 'SL';
              else if (specName.contains('GS') || specName.toLowerCase().contains('gigante')) specName = 'GS';
              else if (specName.contains('SG') || specName.toLowerCase().contains('super')) specName = 'SG';
              else if (specName.contains('DH') || specName.toLowerCase().contains('discesa')) specName = 'DH';
              else if (specName.contains('CL') || specName.toLowerCase().contains('libero')) specName = 'CL';
            }
            bySpecialty[specName] = (bySpecialty[specName] ?? 0) + vol;
          }
        }
      }
    }

    final gymHours = totalGymMinutes ~/ 60;
    final gymMins = totalGymMinutes % 60;

    // Weight difference calc
    double lastWeight =
        filteredWeight.isNotEmpty ? filteredWeight.last.value : 0;
    double prevWeight = filteredWeight.length > 1
        ? filteredWeight[filteredWeight.length - 2].value
        : lastWeight;
    double rawDiff = lastWeight - prevWeight;
    bool isWeightDown = rawDiff < 0;
    bool isWeightSame = rawDiff == 0;
    String displayWeight = user.weight.toStringAsFixed(1);
    String displayDiffVal = rawDiff.abs().toStringAsFixed(1);
    String diffString = '$displayDiffVal kg';

    return Scaffold(
      body: SafeArea(
        child: ListView(
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
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.textHighEmphasis,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pronto per allenarti?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, color: AppTheme.textMediumEmphasis),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.card,
                      backgroundImage: user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child: user.avatarUrl.isEmpty
                          ? const Icon(Icons.person,
                              color: AppTheme.textMediumEmphasis)
                          : null,
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
                  icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
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
                  icon:
                      const Icon(Icons.chevron_right, color: AppTheme.primary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _changeDate(1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // Season Performance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Andamento Stagionale',
                    style: Theme.of(context).textTheme.titleLarge),
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
                              child: Wrap(
                                children: [
                                  Text('CAMBI DI DIR.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textMediumEmphasis)),
                                  Text(' (PALI)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 9,
                                              color: AppTheme.textMediumEmphasis
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
                                          color: AppTheme.textMediumEmphasis)),
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
                                          color: AppTheme.textMediumEmphasis)),
                              TextSpan(text: '$gymMins'),
                              TextSpan(
                                  text: 'm',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppTheme.textMediumEmphasis)),
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
              const Center(
                child: Text('Nessuna attività',
                    style: TextStyle(color: AppTheme.textMediumEmphasis)),
              )
            else ...[
              ...dailyCoachEvents.map((event) {
                final isPast = DateTime.parse(event.date).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                final athleteName = '${user.firstName} ${user.lastName}'.trim();
                final attendee = event.attendees?.cast<Map<String,dynamic>?>().firstWhere(
                  (a) => a != null && (a['id'] == user.email || a['name'] == athleteName),
                  orElse: () => null
                );
                final isPresent = attendee?['isPresent'] == true;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AthleteEventScreen(event: event)));
                    },
                    child: CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(color: const Color(0xFF1C2530), borderRadius: BorderRadius.circular(12)),
                            child: Icon(event.sportCategory == 'ski' ? Icons.downhill_skiing : Icons.fitness_center, color: AppTheme.secondary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(event.title.isNotEmpty ? event.title : 'Evento Coach', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                                    if (isPast && isPresent)
                                      const Icon(Icons.check_circle, color: Colors.green, size: 16)
                                    else if (!isPast)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: isPresent ? Colors.green.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                        child: Text(isPresent ? 'CONFERMATO' : 'DA CONFERMARE', style: TextStyle(fontSize: 10, color: isPresent ? Colors.green : AppTheme.primary, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('${event.startTime} - ${event.endTime}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMediumEmphasis)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10))),
                                    Text(event.location ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMediumEmphasis)),
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
              ...recentSessions.map((session) {
                String sName = session.sportId == 'alpine_skiing' ? 'Alpine Skiing' : session.sportId[0].toUpperCase() + session.sportId.substring(1).replaceAll('_', ' ');
                IconData sIcon = Icons.fitness_center;
                if (session.sportId == 'alpine_skiing') sIcon = PhosphorIcons.snowflake();
                else if (session.sportId.contains('run')) sIcon = Icons.directions_run;
                else if (session.sportId.contains('cycle')) sIcon = Icons.directions_bike;

                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTrainingScreen(sportId: session.sportId, sportName: sName.toUpperCase(), initialSession: session),
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
                              child: Icon(sIcon, color: AppTheme.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sName,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        session.date,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: AppTheme.textMediumEmphasis),
                                      ),
                                    ],
                                  ),
                                  if (session.details != null && session.details!['specialties'] != null && (session.details!['specialties'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                                      child: Text(
                                        session.details!['specialties'][0].toString(),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _formatDuration(session.duration),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMediumEmphasis),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Text('•', style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10)),
                                      ),
                                      Text(
                                        'RPE ${session.effort}/10',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMediumEmphasis),
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
                  builder: (context) => const BodyMetricsScreen(initialMetric: 'weight'),
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
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(displayWeight,
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  Text('kg',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMediumEmphasis)),
                                ],
                              ),
                            ],
                          ),
                          if (filteredWeight.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isWeightSame ? Icons.remove : (isWeightDown ? Icons.trending_down : Icons.trending_up),
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
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nessun dato', style: TextStyle(color: AppTheme.textMediumEmphasis))))
                      else
                        Builder(
                          builder: (context) {
                            // Calculate ranges for dual axis scaling
                            double minW = filteredWeight.map((e) => e.value).reduce((a, b) => a < b ? a : b);
                            double maxW = filteredWeight.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                            double minF = filteredFat.isNotEmpty ? filteredFat.map((e) => e.value).reduce((a, b) => a < b ? a : b) : 10;
                            double maxF = filteredFat.isNotEmpty ? filteredFat.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 25;

                            // Add some padding to ranges
                            minW -= 2; maxW += 2;
                            minF -= 2; maxF += 2;

                            // Helper to scale Fat to Weight range
                            double scaleFat(double fat) {
                              if (maxF == minF) return (maxW + minW) / 2;
                              return ((fat - minF) / (maxF - minF)) * (maxW - minW) + minW;
                            }

                            return SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  minY: minW,
                                  maxY: maxW,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: true,
                                    verticalInterval: filteredWeight.length > 7 ? 7 : 1,
                                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                                    getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1, dashArray: [5, 5]),
                                  ),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        interval: (filteredWeight.length > 2) ? (filteredWeight.length - 1) / 2 : 1.0,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.round();
                                          if (value != idx.toDouble() || idx < 0 || idx >= filteredWeight.length) return const SizedBox.shrink();

                                          final d = DateTime.tryParse(filteredWeight[idx].date);
                                          if (d == null) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: Text(
                                              DateFormat('E d', 'it').format(d),
                                              style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      axisNameWidget: const Text('% Fat', style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, meta) {
                                          // Inverse scale to show % Fat labels
                                          double fatVal = ((value - minW) / (maxW - minW)) * (maxF - minF) + minF;
                                          return Text(fatVal.toStringAsFixed(0), style: const TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold));
                                        },
                                      ),
                                    ),
                                    rightTitles: AxisTitles(
                                      axisNameWidget: const Text('kg Weight', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, meta) {
                                          return Text(value.toStringAsFixed(0), style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold));
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    // Weight Line (Primary Axis)
                                    LineChartBarData(
                                      spots: filteredWeight.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                                      isCurved: true,
                                      color: AppTheme.primary,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: AppTheme.primary, strokeWidth: 1, strokeColor: AppTheme.background),
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        gradient: LinearGradient(
                                          colors: [AppTheme.primary.withValues(alpha: 0.2), Colors.transparent],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                    // Fat Line (Scaled to Weight Axis)
                                    if (filteredFat.isNotEmpty)
                                      LineChartBarData(
                                        spots: filteredFat.asMap().entries.map((e) => FlSpot(e.key.toDouble(), scaleFat(e.value.value))).toList(),
                                        isCurved: true,
                                        color: AppTheme.secondary,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: AppTheme.secondary, strokeWidth: 1, strokeColor: AppTheme.background),
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
                    builder: (context) => const BodyMetricsScreen(initialMetric: 'height'),
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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(heightLogs.last.value.toStringAsFixed(0),
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text('cm',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMediumEmphasis)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.trending_up, size: 16, color: AppTheme.secondary),
                                  const SizedBox(width: 4),
                                  const Text('Growing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
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
                                getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: (heightLogs.length > 2) ? (heightLogs.length - 1) / 2 : 1.0,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.round();
                                      if (value != idx.toDouble() || idx < 0 || idx >= heightLogs.length) return const SizedBox.shrink();
                                      
                                      final d = DateTime.tryParse(heightLogs[idx].date);
                                      if (d == null) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          DateFormat('E d', 'it').format(d),
                                          style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10, fontWeight: FontWeight.bold),
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
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(value.toStringAsFixed(0), style: const TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 11)),
                                    ),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: heightLogs.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                                  isCurved: true,
                                  color: const Color(0xFF9462E5),
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFF9462E5).withValues(alpha: 0.3), Colors.transparent],
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
        child: const Icon(Icons.add, color: AppTheme.background, size: 32),
      ),
    );
  }
}
