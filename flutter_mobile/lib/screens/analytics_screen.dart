import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../utils/strength_pr_utils.dart';
import '../widgets/custom_card.dart';
import '../models/models.dart';
import 'activity_details_screen.dart';
import 'analytics_details_screen.dart';

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
          ? val.toStringAsFixed(2)
          : (val * 2.20462).toStringAsFixed(2);
    } else if (type == 'height') {
      return unitSystem == 'metric'
          ? val.toStringAsFixed(2)
          : (val / 30.48).toStringAsFixed(2);
    } else if (type == 'jump') {
      return unitSystem == 'metric'
          ? val.toStringAsFixed(2)
          : (val * 0.393701).toStringAsFixed(2);
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
    return currentOneRepMaxForExercise(exerciseId, logs);
  }

  double _getLatestBodyVal(List<BodyMetricLog> logs, String type) {
    final filtered = logs.where((l) => l.type == type).toList()
      ..sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return filtered.isNotEmpty ? filtered.first.value : 0.0;
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
    final dropJumpRsiVal = _getLatestJump(appState.jumpLogs, 'drop_jump_rsi');
    final jump45sVal = _getLatestJump(appState.jumpLogs, '45s_jump');
    final slLeftVal = _getLatestJump(appState.jumpLogs, 'single_leg_left');
    final slRightVal = _getLatestJump(appState.jumpLogs, 'single_leg_right');

    // Recent Sessions
    final recentSessions = appState.sessions.take(3).toList();

    // New tests
    final sprint20m = _getLatestBodyVal(appState.bodyLogs, 'sprint_20m');
    final sprint60m = _getLatestBodyVal(appState.bodyLogs, 'sprint_60m');
    final legerVam = _getLatestBodyVal(appState.bodyLogs, 'leger_vam');
    final legerVo2Max = _getLatestBodyVal(appState.bodyLogs, 'leger_vo2max');
    final legerDist = _getLatestBodyVal(appState.bodyLogs, 'leger_distance');
    final balBipedal = _getLatestBodyVal(appState.bodyLogs, 'balance_bipedal');
    final balSingleL = _getLatestBodyVal(appState.bodyLogs, 'balance_single_l');
    final balSingleR = _getLatestBodyVal(appState.bodyLogs, 'balance_single_r');
    final plankFront = _getLatestBodyVal(appState.bodyLogs, 'plank_front');
    final plankSideL = _getLatestBodyVal(appState.bodyLogs, 'plank_side_l');
    final plankSideR = _getLatestBodyVal(appState.bodyLogs, 'plank_side_r');
    final pullupsMax = _getLatestBodyVal(appState.bodyLogs, 'pullups_max');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.shareNetwork,
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
                border: Border.all(
                  color: AppTheme.textLowEmphasis.withValues(alpha: 0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTeamId,
                  isExpanded: true,
                  dropdownColor: AppTheme.card,
                  icon: Icon(Icons.arrow_drop_down,
                      color: AppTheme.textMediumEmphasis),
                  items: appState.teams.map((team) {
                    return DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(
                        team.name,
                        style: TextStyle(
                            color: AppTheme.textHighEmphasis,
                            fontWeight: FontWeight.bold),
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
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Squat Jump',
                            type: 'jump',
                            exerciseId: 'squat_jump'))),
                child: _JumpCard(
                    title: 'Squat Jump',
                    val: squatJumpVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'CM Jump',
                            type: 'jump',
                            exerciseId: 'cm_jump'))),
                child: _JumpCard(
                    title: 'CM Jump',
                    val: cmJumpVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem,
                    isHighlighted: true),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Drop Jump',
                            type: 'jump',
                            exerciseId: 'drop_jump'))),
                child: _JumpCard(
                    title: 'Drop Jump',
                    val: dropJumpVal,
                    rsiVal: dropJumpRsiVal,
                    unit: jumpUnit,
                    unitSystem: unitSystem),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: '45s Jump',
                            type: 'jump',
                            exerciseId: '45s_jump'))),
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
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AnalyticsDetailsScreen(
                                            title: 'Single Leg SX',
                                            type: 'jump',
                                            exerciseId: 'single_leg_left'))),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          color: AppTheme.textHighEmphasis),
                                      children: [
                                        TextSpan(
                                            text: _formatVal(
                                                slLeftVal, 'jump', unitSystem),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text: ' $jumpUnit',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme
                                                    .textMediumEmphasis)),
                                      ],
                                    ),
                                  ),
                                ),
                                Text('SX',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMediumEmphasis)),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color:
                              AppTheme.textLowEmphasis.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AnalyticsDetailsScreen(
                                            title: 'Single Leg DX',
                                            type: 'jump',
                                            exerciseId: 'single_leg_right'))),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          color: AppTheme.textHighEmphasis),
                                      children: [
                                        TextSpan(
                                            text: _formatVal(
                                                slRightVal, 'jump', unitSystem),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        TextSpan(
                                            text: ' $jumpUnit',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme
                                                    .textMediumEmphasis)),
                                      ],
                                    ),
                                  ),
                                ),
                                Text('DX',
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
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AnalyticsDetailsScreen(
                                    title: 'Single Leg Jump',
                                    type: 'jump',
                                    exerciseId: 'single_leg'))),
                        child: Column(
                          children: [
                            if (slLeftVal > 0 || slRightVal > 0)
                              Container(
                                width: 96,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: AppTheme.textLowEmphasis
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 96 *
                                          (slLeftVal /
                                              (slLeftVal + slRightVal)),
                                      decoration: BoxDecoration(
                                          color: AppTheme.secondary,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text('SINGLE LEG',
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
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Back Squat',
                            type: 'pr',
                            exerciseId: 'back_squat'))),
                child: _MaxLoadCard(
                    title: 'Back Squat',
                    val: _getLatestPR(appState.prLogs, 'back_squat'),
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Deadlift',
                            type: 'pr',
                            exerciseId: 'deadlift'))),
                child: _MaxLoadCard(
                    title: 'Deadlift',
                    val: _getLatestPR(appState.prLogs, 'deadlift'),
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Bench Press',
                            type: 'pr',
                            exerciseId: 'bp'))),
                child: _MaxLoadCard(
                    title: 'Bench Press',
                    val: _getLatestPR(appState.prLogs, 'bp'),
                    unit: weightUnit),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Clean & Jerk',
                            type: 'pr',
                            exerciseId: 'clean_jerk'))),
                child: _MaxLoadCard(
                    title: 'Clean & Jerk',
                    val: _getLatestPR(appState.prLogs, 'clean_jerk'),
                    unit: weightUnit),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ANAEROBICO
          Text('VELOCITÀ E AEROBICO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Scatto 20 m',
                            type: 'body',
                            exerciseId: 'sprint_20m'))),
                child: _MaxLoadCard(
                    title: 'Scatto 20 m', val: sprint20m, unit: 's'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Scatto 60 m',
                            type: 'body',
                            exerciseId: 'sprint_60m'))),
                child: _MaxLoadCard(
                    title: 'Scatto 60 m', val: sprint60m, unit: 's'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Léger VAM',
                            type: 'body',
                            exerciseId: 'leger_vam'))),
                child: _MaxLoadCard(
                    title: 'Léger VAM', val: legerVam, unit: 'km/h'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Léger Vo2Max',
                            type: 'body',
                            exerciseId: 'leger_vo2max'))),
                child: _MaxLoadCard(
                    title: 'Léger Vo2Max', val: legerVo2Max, unit: 'ml/kg/min'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Léger Distanza',
                            type: 'body',
                            exerciseId: 'leger_distance'))),
                child: _MaxLoadCard(
                    title: 'Léger Dist.', val: legerDist, unit: 'm'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // EQUILIBRIO
          Text('EQUILIBRIO (Score)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Bipodale',
                            type: 'body',
                            exerciseId: 'balance_bipedal'))),
                child:
                    _MaxLoadCard(title: 'Bipodale', val: balBipedal, unit: ''),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Monopodale SX',
                            type: 'body',
                            exerciseId: 'balance_single_l'))),
                child:
                    _MaxLoadCard(title: 'Mono SX', val: balSingleL, unit: ''),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Monopodale DX',
                            type: 'body',
                            exerciseId: 'balance_single_r'))),
                child:
                    _MaxLoadCard(title: 'Mono DX', val: balSingleR, unit: ''),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // CORE E FORZA
          Text('CORE E FORZA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Plank Frontale',
                            type: 'body',
                            exerciseId: 'plank_front'))),
                child: _MaxLoadCard(
                    title: 'Plank Front.', val: plankFront, unit: 's'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Plank Laterale SX',
                            type: 'body',
                            exerciseId: 'plank_side_l'))),
                child: _MaxLoadCard(
                    title: 'Plank Lat SX', val: plankSideL, unit: 's'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Plank Laterale DX',
                            type: 'body',
                            exerciseId: 'plank_side_r'))),
                child: _MaxLoadCard(
                    title: 'Plank Lat DX', val: plankSideR, unit: 's'),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsDetailsScreen(
                            title: 'Trazioni Massime',
                            type: 'body',
                            exerciseId: 'pullups_max'))),
                child: _MaxLoadCard(
                    title: 'Trazioni Max', val: pullupsMax, unit: 'reps'),
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
                                style: TextStyle(
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
        ],
      ),
    );
  }
}

// ------ WIDGET COMPONENTS ------

class _JumpCard extends StatelessWidget {
  final String title;
  final double val;
  final double? rsiVal;
  final String unit;
  final String unitSystem;
  final bool isHighlighted;

  const _JumpCard({
    required this.title,
    required this.val,
    this.rsiVal,
    required this.unit,
    required this.unitSystem,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(8),
      borderColor:
          isHighlighted ? AppTheme.secondary.withValues(alpha: 0.5) : null,
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
                  style: TextStyle(color: AppTheme.textHighEmphasis),
                  children: [
                    TextSpan(
                        text: val > 0
                            ? (unitSystem == 'metric'
                                ? val.toStringAsFixed(2)
                                : (val * 0.393701).toStringAsFixed(2))
                            : '--',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: unit.isNotEmpty ? ' $unit' : '',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMediumEmphasis)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMediumEmphasis)),
              if (rsiVal != null && rsiVal! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text('RSI: ${rsiVal!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary)),
                ),
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
    final decimals = unit == 'reps' || unit == 'm' ? 0 : 2;
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
              Icon(PhosphorIconsRegular.barbell,
                  size: 16, color: AppTheme.textMediumEmphasis),
            ],
          ),
          const Spacer(),
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMediumEmphasis)),
          RichText(
            text: TextSpan(
              style: TextStyle(color: AppTheme.textHighEmphasis),
              children: [
                TextSpan(
                    text: hasPr ? val.toStringAsFixed(decimals) : '--',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: hasPr
                            ? AppTheme.textHighEmphasis
                            : AppTheme.textMediumEmphasis)),
                if (hasPr)
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMediumEmphasis)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
          CustomCard(
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

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              title: Text(
                  type == 'weight'
                      ? 'Modifica Peso'
                      : type == 'height'
                          ? 'Modifica Altezza'
                          : 'Modifica Massa Grassa',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        hintText: type == 'weight'
                            ? 'es. 65.5'
                            : type == 'height'
                                ? 'es. 172'
                                : 'es. 15.2'),
                    onChanged: (v) => valStr = v,
                    controller: TextEditingController(
                        text: log.value.toString())
                      ..selection = TextSelection.fromPosition(
                          TextPosition(offset: log.value.toString().length)),
                    style: TextStyle(color: AppTheme.textHighEmphasis),
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
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                                  primary: AppTheme.primary,
                                  onPrimary: Colors.white,
                                  surface: AppTheme.card,
                                  onSurface: AppTheme.textHighEmphasis,
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Data',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis)),
                          Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: TextStyle(
                                  color: AppTheme.textHighEmphasis,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Annulla',
                        style: TextStyle(color: AppTheme.textMediumEmphasis))),
                ElevatedButton(
                    onPressed: () {
                      final v = double.tryParse(valStr.replaceAll(',', '.'));
                      if (v != null) {
                        final appState =
                            Provider.of<AppState>(context, listen: false);
                        appState.deleteBodyLog(log.id); // remove old
                        appState.addBodyLog(BodyMetricLog(
                          id: log.id,
                          date: selectedDate.toIso8601String().split('T')[0],
                          type: type,
                          value: v,
                        ));
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Salva')),
              ],
            );
          });
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
                              style: TextStyle(
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
                            Text('+${displayDiff.abs().toStringAsFixed(2)}',
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
                            Text('-${displayDiff.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: type == 'weight'
                                        ? Colors.green
                                        : AppTheme.error)),
                          ] else ...[
                            Icon(PhosphorIconsRegular.minus,
                                size: 12, color: AppTheme.textMediumEmphasis),
                            const SizedBox(width: 2),
                            Text('Stabile',
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
                  icon: Icon(PhosphorIconsRegular.pencilSimple,
                      size: 16, color: AppTheme.textMediumEmphasis),
                  onPressed: () => onEdit(context, log),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(PhosphorIconsRegular.trash,
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
                              style: TextStyle(
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
                    Icon(Icons.chevron_right,
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
