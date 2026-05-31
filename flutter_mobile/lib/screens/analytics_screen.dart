import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import '../models/models.dart';
import 'activity_details_screen.dart';
import 'analytics_details_screen.dart';
import 'health_metrics_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Helper to format values
  String _formatVal(double val, String type, String unitSystem) {
    if (val <= 0) return '--';
    if (type == 'weight') {
      return unitSystem == 'metric'
          ? val.toStringAsFixed(1)
          : (val * 2.20462).toStringAsFixed(1);
    } else if (type == 'height') {
      return unitSystem == 'metric'
          ? val.toStringAsFixed(0)
          : (val / 30.48).toStringAsFixed(2);
    } else if (type == 'jump') {
      return unitSystem == 'metric'
          ? val.toStringAsFixed(1)
          : (val * 0.393701).toStringAsFixed(1);
    }
    return val.toString();
  }

  // Get Latest Jump Helper
  double _getLatestJump(List<JumpLog> logs, String type) {
    final filtered = logs.where((j) => j.type == type).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return filtered.isNotEmpty ? filtered.first.value : 0.0;
  }

  // Get Latest PR by date (not the highest — just the most recently added)
  double _getLatestPR(List<PRLog> logs, String exerciseId) {
    final filtered = logs.where((l) => l.exerciseId == exerciseId).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return filtered.isNotEmpty ? filtered.first.weight : 0.0;
  }

  // Process Logs with Trends Helper
  List<Map<String, dynamic>> _getProcessedLogs(
      List<BodyMetricLog> bodyLogs, String type) {
    final logs = bodyLogs.where((l) => l.type == type).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

    return logs.take(10).toList().asMap().entries.map((e) {
      final index = e.key;
      final log = e.value;
      String? trend;
      double diff = 0;

      if (index < logs.length - 1) {
        final prevVal = logs[index + 1].value;
        diff = log.value - prevVal;
        if (diff > 0) {
          trend = 'up';
        } else if (diff < 0) {
          trend = 'down';
        } else {
          trend = 'equal';
        }
      }
      return {'log': log, 'trend': trend, 'diff': diff};
    }).toList();
  }

  String? _selectedTeamId;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.profile;
    final unitSystem = user?.unitSystem ?? 'metric';

    // Initialize selected team if null and teams exist
    if (_selectedTeamId == null && appState.teams.isNotEmpty) {
      _selectedTeamId = appState.teams.first.id;
    }

    final jumpUnit = unitSystem == 'metric' ? 'cm' : 'in';
    final weightUnit = unitSystem == 'metric' ? 'kg' : 'lbs';

    // Jumps
    final squatJumpVal = _getLatestJump(appState.jumpLogs, 'squat_jump');
    final cmJumpVal = _getLatestJump(appState.jumpLogs, 'cm_jump');
    final dropJumpVal = _getLatestJump(appState.jumpLogs, 'drop_jump');
    final jump45sVal = _getLatestJump(appState.jumpLogs, '45s_jump');
    final slLeftVal = _getLatestJump(appState.jumpLogs, 'single_leg_left');
    final slRightVal = _getLatestJump(appState.jumpLogs, 'single_leg_right');

    // Body Logs
    final recentWeightLogs = _getProcessedLogs(appState.bodyLogs, 'weight');
    final recentHeightLogs = _getProcessedLogs(appState.bodyLogs, 'height');
    final recentFatLogs = _getProcessedLogs(appState.bodyLogs, 'fat');

    // Recent Sessions
    final recentSessions = appState.sessions.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.shareNetwork,
                color: AppTheme.textMediumEmphasis),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appState.teams.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTeamId,
                  isExpanded: true,
                  dropdownColor: AppTheme.card,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMediumEmphasis),
                  items: appState.teams.map((team) {
                    return DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(
                        team.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTeamId = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // JUMP PROFILE
          Text('PROFILO SALTI',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Squat Jump', type: 'jump', exerciseId: 'squat_jump'))),
                child: _JumpCard(
                    title: 'Squat Jump',
                    val: squatJumpVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'CM Jump', type: 'jump', exerciseId: 'cm_jump'))),
                child: _JumpCard(
                    title: 'CM Jump',
                    val: cmJumpVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem,
                    isHighlighted: true),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Drop Jump', type: 'jump', exerciseId: 'drop_jump'))),
                child: _JumpCard(
                    title: 'Drop Jump',
                    val: dropJumpVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: '45s Jump', type: 'jump', exerciseId: '45s_jump'))),
                child: _JumpCard(
                    title: '45s\nJump',
                    val: jump45sVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem),
              ),

              // Box 5: Double Width Single Leg
              CustomCard(
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {},
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                          text: _formatVal(
                                              slLeftVal, 'jump', unitSystem),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text: ' $jumpUnit',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textMediumEmphasis)),
                                    ],
                                  ),
                                ),
                                const Text('SX',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white10),
                        Expanded(
                          child: InkWell(
                            onTap: () {},
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                          text: _formatVal(
                                              slRightVal, 'jump', unitSystem),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text: ' $jumpUnit',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textMediumEmphasis)),
                                    ],
                                  ),
                                ),
                                const Text('DX',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Single Leg Jump', type: 'jump', exerciseId: 'single_leg'))),
                        child: Column(
                          children: [
                            if (slLeftVal > 0 || slRightVal > 0)
                              Container(
                                width: 96,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 96 *
                                          (slLeftVal / (slLeftVal + slRightVal)),
                                      decoration: BoxDecoration(
                                          color: AppTheme.secondary,
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 2),
                            const Text('SINGLE LEG',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMediumEmphasis)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // MAX LOAD
          Text('MAX LOAD',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Back Squat', type: 'pr', exerciseId: 'back_squat'))),
                child: _MaxLoadCard(
                    title: 'Back Squat', 
                    val: _getLatestPR(appState.prLogs, 'back_squat'), 
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Deadlift', type: 'pr', exerciseId: 'deadlift'))),
                child: _MaxLoadCard(
                    title: 'Deadlift', 
                    val: _getLatestPR(appState.prLogs, 'deadlift'), 
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Bench Press', type: 'pr', exerciseId: 'bp'))),
                child: _MaxLoadCard(
                    title: 'Bench Press',
                    val: _getLatestPR(appState.prLogs, 'bp'),
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDetailsScreen(title: 'Clean & Jerk', type: 'pr', exerciseId: 'clean_jerk'))),
                child: _MaxLoadCard(
                    title: 'Clean & Jerk',
                    val: _getLatestPR(appState.prLogs, 'clean_jerk'),
                    unit: weightUnit),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // RECENT SESSIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sessioni Recenti',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _AllSessionsScreen(sessions: appState.sessions),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text('VEDI TUTTI',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary)),
                    Icon(Icons.chevron_right,
                        size: 16, color: AppTheme.secondary),
                  ],
                ),
              ),
            ],
          ),
          ...recentSessions.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ActivityDetailsScreen(session: s)),
                  );
                },
                child: CustomCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: s.sportId == 'alpine_skiing'
                                  ? AppTheme.secondary
                                  : Colors.orange,
                              width: 2),
                        ),
                        child: Icon(
                            s.sportId == 'alpine_skiing'
                                ? PhosphorIconsRegular.mountains
                                : PhosphorIconsRegular.barbell,
                            size: 16,
                            color: s.sportId == 'alpine_skiing'
                                ? AppTheme.secondary
                                : Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.sportId.toUpperCase().replaceAll('_', ' '),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMediumEmphasis),
                                children: [
                                  TextSpan(
                                      text: '${s.date} • ${s.startTime} • '),
                                  TextSpan(
                                      text: 'RPE ${s.effort}',
                                      style: const TextStyle(
                                          color: AppTheme.secondary)),
                                ],
                              ),
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

          const SizedBox(height: 32),

          // CARDIO HEALTH
          Text('SALUTE CARDIO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthMetricsScreen(initialMetric: 'hrv'))),
                  child: const CustomCard(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.favorite, color: AppTheme.primary, size: 28),
                        SizedBox(height: 8),
                        Text('HRV', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Vai ai grafici', style: TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthMetricsScreen(initialMetric: 'resting_hr'))),
                  child: const CustomCard(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.monitor_heart, color: AppTheme.error, size: 28),
                        SizedBox(height: 8),
                        Text('Battiti a Riposo', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Vai ai grafici', style: TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // HISTORY LISTS
          _HistorySection(
              title: 'Storico Peso',
              icon: PhosphorIconsRegular.scales,
              iconColor: AppTheme.secondary,
              logsInfo: recentWeightLogs,
              type: 'weight',
              unitSystem: unitSystem,
              onDelete: (id) => appState.deleteBodyLog(id)),
          const SizedBox(height: 24),
          if (user == null || user.age < 18) ...[
            _HistorySection(
                title: 'Storico Altezza',
                icon: PhosphorIconsRegular.ruler,
                iconColor: Colors.purpleAccent,
                logsInfo: recentHeightLogs,
                type: 'height',
                unitSystem: unitSystem,
                onDelete: (id) => appState.deleteBodyLog(id)),
            const SizedBox(height: 24),
          ],
          _HistorySection(
              title: 'Storico Massa Grassa',
              icon: PhosphorIconsRegular.percent,
              iconColor: Colors.greenAccent,
              logsInfo: recentFatLogs,
              type: 'fat',
              unitSystem: unitSystem,
              onDelete: (id) => appState.deleteBodyLog(id)),
        ],
      ),
    );
  }
}

// ------ WIDGET COMPONENTS ------

class _JumpCard extends StatelessWidget {
  final String title;
  final double val;
  final String unit;
  final String unitSystem;
  final bool isHighlighted;

  const _JumpCard({
    required this.title,
    required this.val,
    required this.unit,
    required this.unitSystem,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(8),
      borderColor: isHighlighted ? AppTheme.secondary.withValues(alpha: 0.5) : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isHighlighted)
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.circle, color: AppTheme.secondary, size: 6),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: val > 0
                            ? (unitSystem == 'metric'
                                ? val.toStringAsFixed(1)
                                : (val * 0.393701).toStringAsFixed(1))
                            : '--',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMediumEmphasis)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMediumEmphasis)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaxLoadCard extends StatelessWidget {
  final String title;
  final double val;
  final String unit;

  const _MaxLoadCard({
    required this.title,
    required this.val,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPr = val > 0;
    return CustomCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              hasPr
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('PR',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary)),
                    )
                  : const SizedBox(width: 4, height: 4),
              const Icon(PhosphorIconsRegular.barbell,
                  size: 16, color: AppTheme.textMediumEmphasis),
            ],
          ),
          const Spacer(),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMediumEmphasis)),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: hasPr ? val.toStringAsFixed(0) : '--',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: hasPr ? Colors.white : AppTheme.textMediumEmphasis)),
                if (hasPr)
                  TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMediumEmphasis)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Map<String, dynamic>> logsInfo;
  final String type;
  final String unitSystem;
  final Function(String) onDelete;

  const _HistorySection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.logsInfo,
    required this.type,
    required this.unitSystem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (logsInfo.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          const CustomCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Nessun dato registrato.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textMediumEmphasis)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        ...logsInfo.map((info) => _buildHistoryItem(context, info)),
      ],
    );
  }

  void onEdit(BuildContext context, BodyMetricLog log) {
    String valStr = log.value.toString();
    DateTime selectedDate = DateTime.parse(log.date);

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: Text(type == 'weight' ? 'Modifica Peso' : type == 'height' ? 'Modifica Altezza' : 'Modifica Massa Grassa', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: type == 'weight' ? 'es. 65.5' : type == 'height' ? 'es. 172' : 'es. 15.2'),
                  onChanged: (v) => valStr = v,
                  controller: TextEditingController(text: log.value.toString())..selection = TextSelection.fromPosition(TextPosition(offset: log.value.toString().length)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            onPrimary: Colors.white,
                            surface: AppTheme.card,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) {
                      setDialogState(() => selectedDate = d);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Data', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                        Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: AppTheme.textMediumEmphasis))),
              ElevatedButton(
                onPressed: () {
                  final v = double.tryParse(valStr.replaceAll(',', '.'));
                  if (v != null) {
                    final appState = Provider.of<AppState>(context, listen: false);
                    appState.deleteBodyLog(log.id); // remove old
                    appState.addBodyLog(
                      BodyMetricLog(
                        id: log.id,
                        date: selectedDate.toIso8601String().split('T')[0],
                        type: type,
                        value: v,
                      )
                    );
                  }
                  Navigator.pop(context);
                }, 
                child: const Text('Salva')
              ),
            ],
          );
        }
      );
    });
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: const Row(
            children: [
              Text('VEDI TUTTI',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary)),
              Icon(Icons.chevron_right, size: 16, color: AppTheme.secondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> info) {
    final log = info['log'] as BodyMetricLog;
    final trend = info['trend'] as String?;
    final diff = info['diff'] as double;

    final displayVal = type == 'weight'
        ? (unitSystem == 'metric' ? log.value : log.value * 2.20462)
        : type == 'height' 
            ? (unitSystem == 'metric' ? log.value : log.value / 30.48)
            : log.value; // fat
    final unit = type == 'weight'
        ? (unitSystem == 'metric' ? 'kg' : 'lbs')
        : type == 'height'
            ? (unitSystem == 'metric' ? 'cm' : 'ft')
            : '%';
    final displayDiff =
        type == 'weight' && unitSystem == 'imperial' ? diff * 2.20462 : diff;

    final dateObj = DateTime.parse(log.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: CustomCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${dateObj.day}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                              height: 1)),
                      Text(_getMon(dateObj.month),
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: iconColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: displayVal
                                  .toStringAsFixed(type == 'weight' ? 1 : 2),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMediumEmphasis)),
                        ],
                      ),
                    ),
                    if (trend != null)
                      Row(
                        children: [
                          if (trend == 'up') ...[
                            Icon(PhosphorIconsRegular.trendUp,
                                size: 12,
                                color: type == 'weight'
                                    ? AppTheme.secondary
                                    : Colors.green),
                            const SizedBox(width: 2),
                            Text('+${displayDiff.abs().toStringAsFixed(1)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: type == 'weight'
                                        ? AppTheme.secondary
                                        : Colors.green)),
                          ] else if (trend == 'down') ...[
                            Icon(PhosphorIconsRegular.trendDown,
                                size: 12,
                                color: type == 'weight'
                                    ? Colors.green
                                    : AppTheme.error),
                            const SizedBox(width: 2),
                            Text('-${displayDiff.abs().toStringAsFixed(1)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: type == 'weight'
                                        ? Colors.green
                                        : AppTheme.error)),
                          ] else ...[
                            const Icon(PhosphorIconsRegular.minus,
                                size: 12, color: AppTheme.textMediumEmphasis),
                            const SizedBox(width: 2),
                            const Text('Stabile',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMediumEmphasis)),
                          ]
                        ],
                      ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.pencilSimple,
                      size: 16, color: AppTheme.textMediumEmphasis),
                  onPressed: () => onEdit(context, log),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.trash,
                      size: 16, color: AppTheme.textMediumEmphasis),
                  onPressed: () => onDelete(log.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  hoverColor: AppTheme.error.withValues(alpha: 0.1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMon(int m) {
    const mons = [
      'GEN',
      'FEB',
      'MAR',
      'APR',
      'MAG',
      'GIU',
      'LUG',
      'AGO',
      'SET',
      'OTT',
      'NOV',
      'DIC'
    ];
    return mons[m - 1];
  }
}

class _AllSessionsScreen extends StatelessWidget {
  final List<TrainingSession> sessions;

  const _AllSessionsScreen({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutte le Sessioni',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final s = sessions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ActivityDetailsScreen(session: s)),
                );
              },
              child: CustomCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: s.sportId == 'alpine_skiing'
                                ? AppTheme.secondary
                                : Colors.orange,
                            width: 2),
                      ),
                      child: Icon(
                          s.sportId == 'alpine_skiing'
                              ? PhosphorIconsRegular.mountains
                              : PhosphorIconsRegular.barbell,
                          size: 16,
                          color: s.sportId == 'alpine_skiing'
                              ? AppTheme.secondary
                              : Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.sportId.toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMediumEmphasis),
                              children: [
                                TextSpan(text: '${s.date} • ${s.startTime} • '),
                                TextSpan(
                                    text: 'RPE ${s.effort}',
                                    style: const TextStyle(
                                        color: AppTheme.secondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textMediumEmphasis),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
