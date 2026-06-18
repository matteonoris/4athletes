import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../providers/app_state.dart';
import '../utils/coach_training_utils.dart';
import '../utils/training_metrics_utils.dart';
import '../utils/time_utils.dart';
import 'analytics_details_screen.dart';
import 'coach_body_metric_detail_screen.dart';
import 'activity_details_screen.dart';
import 'cambi_chart_screen.dart';

class CoachAthleteDetailScreen extends StatefulWidget {
  final String athleteName;
  final String initial;
  final String athleteId;

  const CoachAthleteDetailScreen({
    super.key,
    required this.athleteName,
    required this.initial,
    required this.athleteId,
  });

  @override
  State<CoachAthleteDetailScreen> createState() =>
      _CoachAthleteDetailScreenState();
}

class _CoachAthleteDetailScreenState extends State<CoachAthleteDetailScreen> {
  List<TrainingSession> _sessions = [];
  UserProfile? _profile;
  List<BodyMetricLog> _bodyLogs = [];
  List<JumpLog> _jumpLogs = [];
  List<PRLog> _prLogs = [];
  bool _isLoading = true;
  String? _error;

  // Presenze (from coach events)
  int _skiPresencePercent = 0;
  int _athleticPresencePercent = 0;
  int _extraSciMinutes = 0;
  int _totalCambi = 0;
  Map<String, int> _cambiBySpecialty = {};
  Map<String, Map<String, int>> _cambiByMonthAndSpecialty = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final results = await Future.wait([
        appState.loadAthleteProfile(widget.athleteId),
        appState.loadSessionsForAthlete(widget.athleteId),
        appState.loadBodyLogsForAthlete(widget.athleteId),
        appState.loadJumpLogsForAthlete(widget.athleteId),
        appState.loadPRLogsForAthlete(widget.athleteId),
      ]);

      final sessions = results[1] as List<TrainingSession>;
      _computePresence(appState, sessions);

      if (mounted) {
        setState(() {
          _profile = results[0] as UserProfile?;
          _sessions = sessions;
          _bodyLogs = results[2] as List<BodyMetricLog>;
          _jumpLogs = results[3] as List<JumpLog>;
          _prLogs = results[4] as List<PRLog>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore nel caricamento dei dati';
          _isLoading = false;
        });
      }
    }
  }

  void _computePresence(AppState appState, List<TrainingSession> sessions) {
    final allEvents = appState.coachEvents
        .where((e) => e.status != CoachTrainingUtils.statusCancelled)
        .toList();

    // Ski presence
    final skiEvents = allEvents.where((e) => e.sportCategory == 'ski').toList();
    int skiPresent = 0;
    for (final ev in skiEvents) {
      final attendees = ev.attendees ?? [];
      if (attendees.any((a) =>
          (a['id'] == widget.athleteId || a['name'] == widget.athleteName) &&
          CoachTrainingUtils.isAttendeePresent(a))) {
        skiPresent++;
      }
    }
    _skiPresencePercent = skiEvents.isNotEmpty
        ? (skiPresent / skiEvents.length * 100).round()
        : 0;

    // Athletic presence
    final athleticEvents =
        allEvents.where((e) => e.sportCategory != 'ski').toList();
    int athleticPresent = 0;
    for (final ev in athleticEvents) {
      final attendees = ev.attendees ?? [];
      if (attendees.any((a) =>
          (a['id'] == widget.athleteId || a['name'] == widget.athleteName) &&
          CoachTrainingUtils.isAttendeePresent(a))) {
        athleticPresent++;
      }
    }
    _athleticPresencePercent = athleticEvents.isNotEmpty
        ? (athleticPresent / athleticEvents.length * 100).round()
        : 0;

    int extraMin = 0;
    int cambi = 0;
    Map<String, int> bySpecialty = {};
    Map<String, Map<String, int>> byMonthAndSpecialty = {};
    final sessionEventIds = <String>{};

    void addSkiVolume(String dateStr, int volume, String rawSpecialty) {
      if (volume <= 0) return;

      final specialty = _volumeBucket(rawSpecialty);

      bySpecialty[specialty] = (bySpecialty[specialty] ?? 0) + volume;

      try {
        final date = DateTime.parse(dateStr);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        byMonthAndSpecialty.putIfAbsent(monthKey, () => {});
        byMonthAndSpecialty[monthKey]![specialty] =
            (byMonthAndSpecialty[monthKey]![specialty] ?? 0) + volume;
      } catch (_) {}
    }

    void addSummary(String dateStr, TrainingVolumeSummary summary) {
      cambi += summary.totalSkiDirectionChanges;
      addSkiVolume(dateStr, summary.freeDirectionChanges, 'CL');
      for (final entry in summary.polePassesBySpecialty.entries) {
        addSkiVolume(dateStr, entry.value, entry.key);
      }
      if (summary.trainingDirectionChangesBySpecialty.isEmpty) {
        addSkiVolume(dateStr, summary.trainingDirectionChanges, 'ADD');
      } else {
        for (final entry
            in summary.trainingDirectionChangesBySpecialty.entries) {
          addSkiVolume(dateStr, entry.value, 'ADD ${entry.key}');
        }
      }
    }

    for (final s in sessions) {
      if (s.eventId != null && s.eventId!.isNotEmpty) {
        sessionEventIds.add(s.eventId!);
      }
      if (s.sportId != 'alpine_skiing' &&
          s.sportId != 'ski' &&
          s.sportId != 'skiing' &&
          s.sportId != 'snowboarding') {
        extraMin += TimeUtils.parseDurationToMinutes(s.duration);
      } else {
        final summary = CoachTrainingUtils.volumeFromDetails(s.details);
        addSummary(s.date, summary);
      }
    }

    for (final ev in skiEvents) {
      if (ev.status != CoachTrainingUtils.statusCompleted) continue;
      if (sessionEventIds.contains(ev.id)) continue;
      final attendees = ev.attendees ?? [];
      final athleteName = widget.athleteName;
      final attendee = attendees.cast<Map<String, dynamic>?>().firstWhere(
          (a) =>
              a != null &&
              (a['id'] == widget.athleteId || a['name'] == athleteName),
          orElse: () => null);
      if (attendee != null && CoachTrainingUtils.isAttendeePresent(attendee)) {
        final summary =
            CoachTrainingUtils.volumeFromEventAttendee(ev, attendee);
        addSummary(ev.date, summary);
      }
    }

    _extraSciMinutes = extraMin;
    _totalCambi = cambi;
    _cambiBySpecialty = bySpecialty;
    _cambiByMonthAndSpecialty = byMonthAndSpecialty;
  }

  // ─── Jump helpers ────────────────────────────────────────────
  double _latestJump(String type) {
    final filtered = _jumpLogs.where((j) => j.type == type).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return filtered.isNotEmpty ? filtered.first.value : 0;
  }

  double _latestPR(String exerciseId) {
    final filtered = _prLogs.where((l) => l.exerciseId == exerciseId).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return filtered.isNotEmpty ? filtered.first.weight : 0;
  }

  List<BodyMetricLog> _logsOf(String type) => _bodyLogs
      .where((l) => l.type == type)
      .toList()
    ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  // ─── Sport helpers ───────────────────────────────────────────
  String _sportLabel(String id) {
    const map = {
      'alpine_skiing': 'Alpine Skiing',
      'weightlifting': 'Weightlifting',
      'powerlifting': 'Powerlifting',
      'crossfit': 'CrossFit',
      'bodybuilding': 'Bodybuilding',
      'running': 'Running Road',
      'trail_running': 'Trail Running',
      'cycling': 'Cycling',
      'swimming': 'Swimming',
      'athletic_prep': 'Preparazione Atletica',
      'stretching': 'Stretching',
      'yoga': 'Yoga',
      'pilates': 'Pilates',
      'other': 'Altro',
    };
    return map[id] ?? id;
  }

  IconData _sportIcon(String id) {
    if (id == 'alpine_skiing') return Icons.ac_unit;
    if ([
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding',
      'athletic_prep'
    ].contains(id)) {
      return Icons.fitness_center;
    }
    if (id.contains('running')) return Icons.directions_run;
    if (id.contains('cycling')) return Icons.directions_bike;
    if (id == 'swimming') return Icons.pool;
    return Icons.sports;
  }

  Color _sportColor(String id) {
    if (id == 'alpine_skiing') return AppTheme.primary;
    if ([
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding',
      'athletic_prep'
    ].contains(id)) {
      return const Color(0xFFFF7A00);
    }
    if (id.contains('running')) return Colors.greenAccent;
    return AppTheme.secondary;
  }

  String _formatDuration(int minutes) {
    return TimeUtils.formatDuration(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: TextStyle(color: AppTheme.textMediumEmphasis)),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAll();
            },
            child: const Text('Riprova')),
      ]),
    );
  }

  Widget _buildContent() {
    final weightLogs = _logsOf('weight');
    final heightLogs = _logsOf('height');
    final showHeight =
        heightLogs.isNotEmpty && (_profile == null || _profile!.age < 18);

    // All jump types present for this athlete
    final jumpTypes = _jumpLogs
        .map((j) => j.type)
        .where((t) => t != 'drop_jump_rsi')
        .toSet()
        .toList();

    // PR exercises present for this athlete
    final prExercises = _prLogs.map((l) => l.exerciseId).toSet().toList();

    // Body metric types
    final bodyTypes = _bodyLogs.map((l) => l.type).toSet().toList();
    final additionalMetrics =
        bodyTypes.where((t) => _bodyLabels.containsKey(t)).toList();

    return CustomScrollView(
      slivers: [
        // ─── Sticky Header ───────────────────────────────────
        SliverAppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  BoxDecoration(color: AppTheme.card, shape: BoxShape.circle),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(widget.initial,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.athleteName,
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              if (_profile?.skiClub != null)
                Text(_profile!.skiClub!,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 11)),
            ]),
          ]),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.textMediumEmphasis),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadAll();
              },
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Stats Row ─────────────────────────────
                _buildStatsRow(),
                const SizedBox(height: 12),

                // ─── Cambi di Direzione Card ───────────────
                _buildCambiCard(),
                const SizedBox(height: 20),
                _buildDrylandPrepCard(),
                const SizedBox(height: 20),

                // ─── Peso & Altezza mini charts ────────────
                if (weightLogs.isNotEmpty || showHeight) ...[
                  Row(children: [
                    if (weightLogs.isNotEmpty)
                      Expanded(
                          child: _buildMiniChart(
                        title: 'Peso',
                        icon: PhosphorIconsRegular.scales,
                        logs: weightLogs,
                        color: AppTheme.secondary,
                        unit: 'kg',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CoachBodyMetricDetailScreen(
                                title: 'Peso',
                                type: 'weight',
                                logs: weightLogs,
                                athleteName: widget.athleteName,
                              ),
                            )),
                      )),
                    if (weightLogs.isNotEmpty && showHeight)
                      const SizedBox(width: 12),
                    if (showHeight)
                      Expanded(
                          child: _buildMiniChart(
                        title: 'Altezza',
                        icon: PhosphorIconsRegular.ruler,
                        logs: heightLogs,
                        color: Colors.purpleAccent,
                        unit: 'cm',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CoachBodyMetricDetailScreen(
                                title: 'Altezza',
                                type: 'height',
                                logs: heightLogs,
                                athleteName: widget.athleteName,
                              ),
                            )),
                      )),
                  ]),
                  const SizedBox(height: 20),
                ],

                // ─── Profilo Salto ─────────────────────────
                if (jumpTypes.isNotEmpty) ...[
                  _buildSectionTitle(
                      Icons.trending_up, 'Profilo Salto', AppTheme.secondary),
                  const SizedBox(height: 12),
                  _buildJumpGrid(jumpTypes),
                  const SizedBox(height: 20),
                ],

                // ─── Massimali 1RM ─────────────────────────
                if (prExercises.isNotEmpty) ...[
                  _buildSectionTitle(PhosphorIconsRegular.barbell,
                      'Massimali (1RM)', const Color(0xFFFF7A00)),
                  const SizedBox(height: 12),
                  _buildPRGrid(prExercises),
                  const SizedBox(height: 20),
                ],

                // ─── Altri Test & Metriche ──────────────────
                if (additionalMetrics.isNotEmpty) ...[
                  _buildSectionTitle(PhosphorIconsRegular.heartbeat,
                      'Test & Metriche (Recupero/Sonno)', AppTheme.secondary),
                  const SizedBox(height: 12),
                  _buildBodyGrid(additionalMetrics),
                  const SizedBox(height: 20),
                ],

                // ─── Storico Attività ──────────────────────
                _buildSectionTitle(
                    Icons.history, 'Storico Attività', AppTheme.primary),
                const SizedBox(height: 12),
                if (_sessions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16)),
                    child: Center(
                        child: Text('Nessuna sessione registrata',
                            style:
                                TextStyle(color: AppTheme.textMediumEmphasis))),
                  )
                else
                  ..._sessions.take(10).map((s) => _buildSessionRow(s)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Stats Row ─────────────────────────────────────────────────
  Widget _buildDrylandPrepCard() {
    final drylandSessions = _sessions.where((session) =>
        session.sportId != 'alpine_skiing' &&
        session.sportId != 'ski' &&
        session.sportId != 'skiing' &&
        session.sportId != 'snowboarding');
    final activities = drylandSessions
        .map((session) => TrainingActivity.fromTrainingSession(session))
        .where((activity) => activity.status != ActivityStatus.cancelled)
        .toList();

    final strength = TrainingMetricsUtils.strengthSummary(activities);
    final plyo = TrainingMetricsUtils.plyometricSummary(activities);
    final speed = TrainingMetricsUtils.speedAgilitySummary(activities);
    final endurance = TrainingMetricsUtils.enduranceSummary(activities);
    final hasData = activities.isNotEmpty ||
        strength.totalSets > 0 ||
        plyo.totalContacts > 0 ||
        speed.drillCount > 0 ||
        endurance.durationSeconds > 0;

    if (!hasData) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsRegular.barbell,
                  color: Color(0xFFFF7A00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preparazione atletica',
                  style: TextStyle(
                    color: AppTheme.textHighEmphasis,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _prepMetric('Ore', (_extraSciMinutes / 60).toStringAsFixed(1)),
              if (strength.volumeKg > 0)
                _prepMetric('Volume kg', strength.volumeKg.round().toString()),
              if (strength.totalSets > 0)
                _prepMetric('Serie forza', strength.totalSets.toString()),
              if (plyo.totalContacts > 0)
                _prepMetric('Contatti', plyo.totalContacts.toString()),
              if (speed.drillCount > 0)
                _prepMetric('Drill', speed.drillCount.toString()),
              if (endurance.durationSeconds > 0)
                _prepMetric(
                  'Resistenza',
                  '${(endurance.durationSeconds / 60).round()}m',
                ),
              if (endurance.zone23Seconds > 0)
                _prepMetric(
                    'Z2-Z3', '${(endurance.zone23Seconds / 60).round()}m'),
              if (endurance.zone45Seconds > 0)
                _prepMetric(
                    'Z4-Z5', '${(endurance.zone45Seconds / 60).round()}m'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prepMetric(String label, String value) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final extraLabel = _formatDuration(_extraSciMinutes);
    return Row(children: [
      Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text('PRESENZE',
              style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('$_skiPresencePercent% Sci\n$_athleticPresencePercent% Atl',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.2)),
        ]),
      )),
      const SizedBox(width: 10),
      Expanded(
          child:
              _buildStatCard('EXTRA SCI', extraLabel, const Color(0xFFFF7A00))),
    ]);
  }

  Widget _buildCambiCard() {
    final sortedVolumeEntries = _cambiBySpecialty.entries.toList()
      ..sort((a, b) =>
          _skiVolumeSortIndex(a.key).compareTo(_skiVolumeSortIndex(b.key)));

    return GestureDetector(
      onTap: () {
        if (_totalCambi == 0) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CambiChartScreen(
                      athleteName: widget.athleteName,
                      cambiByMonthAndSpecialty: _cambiByMonthAndSpecialty,
                    )));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.show_chart,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CAMBI DI DIR. TOTALI',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('$_totalCambi',
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.w900,
                          fontSize: 22)),
                  const SizedBox(height: 6),
                  if (_cambiBySpecialty.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: sortedVolumeEntries.map((e) {
                        final col = _colorForSkiVolumeKey(e.key);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: col, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('${e.key} ${e.value}',
                                style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 11)),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis),
          ],
        ),
      ),
    );
  }

  int _skiVolumeSortIndex(String key) {
    const order = ['CL', 'SL', 'GS', 'SG', 'DH', 'SX', 'ADD'];
    if (key.startsWith('ADD ')) {
      final specialty = key.substring(4);
      final specialtyIndex = order.indexOf(specialty);
      return order.length +
          (specialtyIndex == -1 ? order.length : specialtyIndex);
    }
    final index = order.indexOf(key);
    return index == -1 ? order.length : index;
  }

  String _volumeBucket(String rawSpecialty) {
    final raw = rawSpecialty.trim().toUpperCase();
    if (raw == 'ADD') return 'ADD';
    if (raw.startsWith('ADD ')) {
      return 'ADD ${CoachTrainingUtils.normalizeSpecialty(raw.substring(4))}';
    }
    return CoachTrainingUtils.normalizeSpecialty(raw);
  }

  Color _colorForSkiVolumeKey(String key) {
    if (key == 'CL') return Colors.orangeAccent;
    if (key == 'SL') return AppTheme.secondary;
    if (key == 'GS') return Colors.lightBlue;
    if (key == 'SG') return Colors.greenAccent;
    if (key == 'DH') return Colors.purpleAccent;
    if (key == 'SX') return Colors.redAccent;
    if (key.startsWith('ADD ')) return Colors.amberAccent;
    if (key == 'ADD') return Colors.amberAccent;
    return Colors.grey;
  }

  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontWeight: FontWeight.bold,
                fontSize: 9,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.w900, fontSize: 20)),
      ]),
    );
  }

  // ─── Mini inline chart ─────────────────────────────────────────
  Widget _buildMiniChart({
    required String title,
    required IconData icon,
    required List<BodyMetricLog> logs,
    required Color color,
    required String unit,
    required VoidCallback onTap,
  }) {
    final latest = logs.last.value;
    final spots =
        List.generate(logs.length, (i) => FlSpot(i.toDouble(), logs[i].value));
    double minY = logs.map((l) => l.value).reduce((a, b) => a < b ? a : b);
    double maxY = logs.map((l) => l.value).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.2 + 0.5;
    minY = minY - pad;
    maxY = maxY + pad;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: AppTheme.textMediumEmphasis, size: 14),
          ]),
          const SizedBox(height: 4),
          Text('${latest.toStringAsFixed(2)} $unit',
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const Spacer(),
          SizedBox(
            height: 48,
            child: LineChart(LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                )
              ],
            )),
          ),
          const SizedBox(height: 4),
          Text(logs.last.date,
              style:
                  TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 9)),
        ]),
      ),
    );
  }

  // ─── Jump grid ─────────────────────────────────────────────────
  static const Map<String, String> _jumpLabels = {
    'squat_jump': 'SQUAT\nJUMP',
    'cm_jump': 'CM\nJUMP',
    'drop_jump': 'DROP\nJUMP',
    '45s_jump': '45s\nJUMP',
    'single_leg_left': 'SL\nSINISTRA',
    'single_leg_right': 'SL\nDESTRA',
    'single_leg': 'SINGLE\nLEG',
  };

  Widget _buildJumpGrid(List<String> types) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: types.map((t) {
        final val = _latestJump(t);
        final label = _jumpLabels[t] ?? t.toUpperCase().replaceAll('_', '\n');
        final rsiVal = t == 'drop_jump' ? _latestJump('drop_jump_rsi') : 0.0;
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticsDetailsScreen(
                  title: label.replaceAll('\n', ' '),
                  type: 'jump',
                  exerciseId: t,
                  preloadedLogs: _jumpLogs,
                  isReadOnly: false,
                  athleteId: widget.athleteId,
                ),
              )),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(children: [
                  TextSpan(
                      text: val > 0 ? val.toStringAsFixed(2) : '--',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (val > 0)
                    TextSpan(
                        text: ' cm',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textMediumEmphasis)),
                ]),
              ),
              if (rsiVal > 0) ...[
                const SizedBox(height: 3),
                Text('RSI ${rsiVal.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary)),
              ],
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMediumEmphasis)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ─── PR grid ───────────────────────────────────────────────────
  static const Map<String, String> _prLabels = {
    'back_squat': 'Back Squat',
    'deadlift': 'Deadlift',
    'bp': 'Bench Press',
    'clean_jerk': 'Clean & Jerk',
    'snatch': 'Snatch',
    'front_squat': 'Front Squat',
    'rdl': 'RDL',
    'ohp': 'OHP',
    'hip_thrust': 'Hip Thrust',
    'clean': 'Clean',
  };

  Widget _buildPRGrid(List<String> exercises) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: exercises.map((ex) {
        final val = _latestPR(ex);
        final label = _prLabels[ex] ?? ex.replaceAll('_', ' ');
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticsDetailsScreen(
                  title: label,
                  type: 'pr',
                  exerciseId: ex,
                  preloadedLogs: _prLogs,
                  isReadOnly: false,
                  athleteId: widget.athleteId,
                ),
              )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: val > 0 ? val.toStringAsFixed(2) : '--',
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  if (val > 0)
                    TextSpan(
                        text: ' kg',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ─── Body Metric Grid ───────────────────────────────────────────
  static const Map<String, String> _bodyLabels = {
    'sprint_20m': 'Scatto 20m',
    'sprint_60m': 'Scatto 60m',
    'balance_bipedal': 'Eq. Bipodale',
    'balance_single_l': 'Eq. Mono SX',
    'balance_single_r': 'Eq. Mono DX',
    'plank_front': 'Plank Front.',
    'plank_side_l': 'Plank SX',
    'plank_side_r': 'Plank DX',
    'pullups_max': 'Trazioni',
    'recovery_score': 'Recovery Score',
    'sleep_score': 'Sleep Score',
    'leger_vam': 'Léger VAM',
    'leger_vo2max': 'Léger Vo2Max',
    'leger_distance': 'Léger Dist.',
  };

  static const Map<String, String> _bodyUnits = {
    'sprint_20m': 's',
    'sprint_60m': 's',
    'balance_bipedal': '',
    'balance_single_l': '',
    'balance_single_r': '',
    'plank_front': 's',
    'plank_side_l': 's',
    'plank_side_r': 's',
    'pullups_max': 'reps',
    'recovery_score': '',
    'sleep_score': '',
    'leger_vam': 'km/h',
    'leger_vo2max': 'ml/kg/min',
    'leger_distance': 'm',
  };

  int _bodyDecimalPlaces(String type) {
    const integerMetrics = {
      'leger_distance',
      'pullups_max',
      'recovery_score',
      'sleep_score',
    };
    return integerMetrics.contains(type) ? 0 : 2;
  }

  Widget _buildBodyGrid(List<String> types) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: types.map((t) {
        final logs = _logsOf(t);
        final val = logs.isNotEmpty ? logs.last.value : 0.0;
        final label = _bodyLabels[t] ?? t;
        final unit = _bodyUnits[t] ?? '';
        final decimals = _bodyDecimalPlaces(t);
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticsDetailsScreen(
                  title: label,
                  type: 'body',
                  exerciseId: t,
                  preloadedLogs: _bodyLogs,
                  isReadOnly: false,
                  athleteId: widget.athleteId,
                ),
              )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: val > 0 ? val.toStringAsFixed(decimals) : '--',
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  if (val > 0 && unit.isNotEmpty)
                    TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                            color: AppTheme.textMediumEmphasis, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ─── Section title ─────────────────────────────────────────────
  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    ]);
  }

  // ─── Session row ───────────────────────────────────────────────
  Widget _buildSessionRow(TrainingSession session) {
    final color = _sportColor(session.sportId);
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ActivityDetailsScreen(session: session, prLogs: _prLogs))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_sportIcon(session.sportId), color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_sportLabel(session.sportId),
                  style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 3),
              Row(children: [
                Text(session.date,
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 11)),
                const SizedBox(width: 8),
                Icon(Icons.access_time,
                    color: AppTheme.textMediumEmphasis, size: 11),
                const SizedBox(width: 3),
                Text(TimeUtils.formatDuration(session.duration),
                    style: TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 11)),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right,
              color: AppTheme.textMediumEmphasis, size: 18),
        ]),
      ),
    );
  }
}
