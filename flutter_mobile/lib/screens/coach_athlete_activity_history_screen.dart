import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import 'activity_details_screen.dart';

class CoachAthleteActivityHistoryScreen extends StatelessWidget {
  final String athleteName;
  final List<TrainingSession> sessions;
  final List<PRLog> prLogs;

  const CoachAthleteActivityHistoryScreen({
    super.key,
    required this.athleteName,
    required this.sessions,
    this.prLogs = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storico attività',
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              athleteName,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                'Nessun allenamento registrato',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: sessions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${sessions.length} ${sessions.length == 1 ? 'allenamento svolto' : 'allenamenti svolti'}',
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final session = sessions[index - 1];
                return CoachActivitySessionTile(
                  key: ValueKey('coach-activity-${session.id}'),
                  session: session,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityDetailsScreen(
                        session: session,
                        prLogs: prLogs,
                        readOnly: true,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CoachActivitySessionTile extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onTap;

  const CoachActivitySessionTile({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _sportColor(session.sportId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.subtleBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(_sportIcon(session.sportId), color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sportLabel(session.sportId),
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.date,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            color: AppTheme.textMediumEmphasis,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            TimeUtils.formatDuration(session.duration),
                            style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textMediumEmphasis,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sportLabel(String id) {
    return WorkoutCatalog.displayName(id);
  }

  IconData _sportIcon(String id) {
    if (['alpine_skiing', 'ski', 'skiing', 'snowboarding'].contains(id)) {
      return Icons.ac_unit;
    }
    if ([
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding',
      'athletic_prep',
    ].contains(id)) {
      return Icons.fitness_center;
    }
    if (id.contains('running')) return Icons.directions_run;
    if (id.contains('cycling')) return Icons.directions_bike;
    if (id == 'swimming') return Icons.pool;
    return Icons.sports;
  }

  Color _sportColor(String id) {
    if (['alpine_skiing', 'ski', 'skiing', 'snowboarding'].contains(id)) {
      return AppTheme.primary;
    }
    if ([
      'weightlifting',
      'powerlifting',
      'crossfit',
      'bodybuilding',
      'athletic_prep',
    ].contains(id)) {
      return const Color(0xFFFF7A00);
    }
    if (id.contains('running')) return Colors.green;
    return AppTheme.secondary;
  }
}
