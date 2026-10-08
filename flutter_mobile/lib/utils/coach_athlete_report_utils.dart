import '../models/models.dart';
import 'coach_training_utils.dart';
import 'time_utils.dart';

class AthletePresence {
  final int skiPercent;
  final int athleticPercent;

  const AthletePresence({
    required this.skiPercent,
    required this.athleticPercent,
  });
}

class CoachAthleteReportUtils {
  static const _skiSportIds = {
    'alpine_skiing',
    'ski',
    'skiing',
    'snowboarding',
  };

  static bool isPreparationSport(String sportId) =>
      !_skiSportIds.contains(sportId.toLowerCase());

  static int preparationMinutes({
    required String sportId,
    required dynamic duration,
    Map<String, dynamic>? details,
  }) {
    if (!isPreparationSport(sportId) || details?['status'] == 'cancelled') {
      return 0;
    }
    return TimeUtils.parseDurationToMinutes(duration);
  }

  static String preparationHoursLabel(int minutes) =>
      '${(minutes / 60).toStringAsFixed(1)}h';

  static AthletePresence presence({
    required Iterable<CalendarEvent> events,
    required String athleteId,
    required String athleteName,
    String? teamId,
  }) {
    var skiEvents = 0;
    var skiPresent = 0;
    var athleticEvents = 0;
    var athleticPresent = 0;

    for (final event in events) {
      if (event.status == CoachTrainingUtils.statusCancelled ||
          (teamId != null &&
              teamId.isNotEmpty &&
              !CoachTrainingUtils.teamIdsForEvent(event).contains(teamId))) {
        continue;
      }

      final present = (event.attendees ?? []).any((attendee) =>
          (attendee['id'] == athleteId || attendee['name'] == athleteName) &&
          CoachTrainingUtils.isAttendeePresent(attendee));
      if (event.sportCategory == 'ski') {
        skiEvents++;
        if (present) skiPresent++;
      } else {
        athleticEvents++;
        if (present) athleticPresent++;
      }
    }

    return AthletePresence(
      skiPercent: skiEvents == 0 ? 0 : (skiPresent / skiEvents * 100).round(),
      athleticPercent: athleticEvents == 0
          ? 0
          : (athleticPresent / athleticEvents * 100).round(),
    );
  }
}
