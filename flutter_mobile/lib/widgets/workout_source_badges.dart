import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/workout_creation_models.dart';

class WorkoutSourceBadges extends StatelessWidget {
  final bool coachCreated;
  final bool merged;

  const WorkoutSourceBadges({
    super.key,
    required this.coachCreated,
    required this.merged,
  });

  factory WorkoutSourceBadges.forSession(
    TrainingSession session, {
    Key? key,
  }) {
    return WorkoutSourceBadges(
      key: key,
      coachCreated: WorkoutProvenance.isCoachCreated(session),
      merged: WorkoutProvenance.isMerged(session),
    );
  }

  bool get isEmpty => !coachCreated && !merged;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const ValueKey('workout_source_badges'),
      spacing: 6,
      runSpacing: 6,
      children: [
        if (coachCreated)
          const _SourceBadge(
            label: 'ALLENATORE',
            icon: Icons.sports,
            color: AppTheme.secondary,
          ),
        if (merged)
          const _SourceBadge(
            label: 'MERGE',
            icon: Icons.merge,
            color: AppTheme.primary,
          ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SourceBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
