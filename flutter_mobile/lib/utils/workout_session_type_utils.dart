import '../data/dryland_prep_types.dart';
import '../data/workout_catalog.dart';
import '../models/models.dart';

/// Changes classification without rebuilding the recorded workout or its data.
class WorkoutSessionTypeUtils {
  static TrainingSession changeType(
    TrainingSession session,
    WorkoutActivityDefinition activity,
  ) {
    if (session.sportId == activity.id) return session;
    final details = Map<String, dynamic>.from(session.details ?? const {});
    final rawDraft = details['workoutDraft'];
    final draft = rawDraft is Map
        ? rawDraft.map((key, value) => MapEntry(key.toString(), value))
        : null;
    final oldNames = {
      session.sportId.toLowerCase(),
      WorkoutCatalog.displayName(session.sportId).toLowerCase(),
      if (draft?['activityName'] is String)
        (draft!['activityName'] as String).trim().toLowerCase(),
    };
    String updatedTitle(dynamic title) {
      final value = title?.toString().trim() ?? '';
      return value.isEmpty || oldNames.contains(value.toLowerCase())
          ? activity.name
          : value;
    }

    details['activity_type_user_overridden'] = true;
    details.putIfAbsent(
        'activity_type_original_sport_id', () => session.sportId);
    details['activityCategory'] = activity.category;
    details['activityDomain'] =
        activity.section == WorkoutCatalogSection.preparation
            ? 'dryland'
            : 'sport';
    details['title'] = updatedTitle(details['title'] ?? draft?['title']);
    if (activity.section == WorkoutCatalogSection.preparation) {
      details['prepType'] = DrylandPrepTypes.fromCategory(activity.category).id;
    } else {
      details.remove('prepType');
    }
    // Modes and protocols belong to a particular activity. Recorded blocks,
    // phases, metrics, notes and external identifiers remain untouched.
    for (final key in [
      'activityMode',
      'legacyActivityMode',
      'protocolId',
      'protocolName'
    ]) {
      details.remove(key);
      draft?.remove(key);
    }
    if (draft != null) {
      draft['activityId'] = activity.id;
      draft['activityName'] = activity.name;
      draft['activityCategory'] = activity.category;
      draft['editorKind'] = activity.editorKind;
      draft['title'] = updatedTitle(draft['title']);
      details['workoutDraft'] = draft;
    }
    return TrainingSession(
      id: session.id,
      sportId: activity.id,
      date: session.date,
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      effort: session.effort,
      eventId: session.eventId,
      details: details,
    );
  }
}
