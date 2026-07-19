import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../utils/coach_training_utils.dart';

class TrainingActivityService {
  const TrainingActivityService();

  WorkoutTemplate savePersonalActivityAsTemplate(
    TrainingActivity activity, {
    required String templateId,
    required String name,
    String? description,
    required String ownerId,
    DateTime? now,
  }) {
    return WorkoutTemplate.fromActivity(
      activity,
      id: templateId,
      name: name,
      description: description,
      ownerType: TemplateOwnerType.athlete,
      ownerId: ownerId,
      createdBy: ownerId,
      now: now,
    );
  }

  TrainingActivity activityFromSession(
    TrainingSession session, {
    String? athleteId,
    String? title,
  }) {
    return TrainingActivity.fromTrainingSession(
      session,
      athleteId: athleteId,
      title: title,
    );
  }

  WorkoutTemplate saveActivityAsTemplate(
    TrainingActivity activity, {
    required String templateId,
    required String name,
    String? description,
    required String ownerType,
    required String ownerId,
    String? teamId,
    required String createdBy,
    String? activityMode,
    String? protocolId,
    String? structureMode,
    int? plannedDurationMinutes,
    String visibility = 'private',
    DateTime? now,
  }) {
    return WorkoutTemplate.fromActivity(
      activity,
      id: templateId,
      name: name,
      description: description,
      ownerType: ownerType,
      ownerId: ownerId,
      teamId: teamId,
      createdBy: createdBy,
      activityMode: activityMode,
      protocolId: protocolId,
      structureMode: structureMode,
      plannedDurationMinutes: plannedDurationMinutes,
      visibility: visibility,
      now: now,
    );
  }

  TrainingActivity instantiateTemplate(
    WorkoutTemplate template, {
    required String activityId,
    required String athleteId,
    String? coachId,
    String? teamId,
    List<String> teamIds = const [],
    String source = ActivitySource.athlete,
    String status = ActivityStatus.completed,
    required String date,
    required String startTime,
    required String endTime,
    required String duration,
    String? title,
    String? location,
  }) {
    return template.instantiateActivity(
      id: activityId,
      athleteId: athleteId,
      coachId: coachId,
      teamId: teamId,
      teamIds: teamIds,
      source: source,
      status: status,
      date: date,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      title: title,
      location: location,
    );
  }

  TrainingActivity duplicateActivity(
    TrainingActivity activity, {
    required String newId,
    required String date,
    String? startTime,
    String? endTime,
    String? title,
  }) {
    return activity.copyWith(
      id: newId,
      date: date,
      startTime: startTime ?? activity.startTime,
      endTime: endTime ?? activity.endTime,
      title: title ?? activity.title,
      status: ActivityStatus.completed,
      source: ActivitySource.athlete,
      createdByCoach: false,
      linkedCoachEventId: '',
      athleteModified: false,
    );
  }

  Map<String, dynamic> buildCoachDrylandSessionDetails(
    CalendarEvent event,
    Map<String, dynamic> attendee,
  ) {
    final technicalDetails = Map<String, dynamic>.from(
      event.technicalDetails ?? const {},
    );
    final planned = technicalDetails['plannedDrylandSession'];
    final actual = attendee['actualDrylandDetails'];
    final blocks = _blocksFromAny(actual) ?? _blocksFromAny(planned);
    final category = _categoryFromEvent(event, planned);
    final plannedMap =
        planned is Map ? Map<String, dynamic>.from(planned) : null;
    final rawWorkoutDraft = technicalDetails['workoutDraft'];
    final workoutDraft = rawWorkoutDraft is Map
        ? Map<String, dynamic>.from(rawWorkoutDraft)
        : null;
    final activityDomain =
        category == ActivityCategory.sport ? 'sport' : 'dryland';

    final details = <String, dynamic>{
      'schemaVersion': workoutDraft == null ? 2 : 3,
      'activityDomain': activityDomain,
      'activityCategory': category,
      if (workoutDraft != null) 'workoutDraft': workoutDraft,
      if (workoutDraft?['activityMode'] != null)
        'activityMode': workoutDraft!['activityMode'],
      if (workoutDraft?['protocolId'] != null)
        'protocolId': workoutDraft!['protocolId'],
      if (workoutDraft?['protocolName'] != null)
        'protocolName': workoutDraft!['protocolName'],
      if (workoutDraft?['structureMode'] != null)
        'structureMode': workoutDraft!['structureMode'],
      if (workoutDraft?['structureMode'] != null)
        'usesPhases': workoutDraft!['structureMode'] == 'phased',
      if (plannedMap?['prepType'] != null) 'prepType': plannedMap!['prepType'],
      if (workoutDraft?['structureMode'] == null &&
          plannedMap?['usesPhases'] != null)
        'usesPhases': plannedMap!['usesPhases'],
      if (plannedMap?['sportType'] != null)
        'sportType': plannedMap!['sportType'],
      'source': ActivitySource.coach,
      'from_calendar': true,
      'status': ActivityStatus.completed,
      'title': event.title,
      'specialty': event.drylandSpecialty,
      'technicalDetails': technicalDetails,
      'plannedDrylandSession': planned,
      if (actual != null) 'actualDrylandDetails': actual,
      if (blocks != null) 'blocks': blocks,
      if (workoutDraft?['phases'] is List)
        'prescription': {
          'startTime': workoutDraft!['plannedStartTime'],
          'endTime': workoutDraft['plannedEndTime'],
          'durationMinutes': workoutDraft['plannedDurationMinutes'],
          'phases': workoutDraft['phases'],
        },
      'athleteModified': attendee['modifiedByAthlete'] == true ||
          attendee['athleteModified'] == true ||
          actual != null,
      'createdByCoach': true,
      'linkedCoachEventId': event.id,
      if (attendee['rpe'] != null) 'rpe': attendee['rpe'],
      if (attendee['pain'] != null) 'pain': attendee['pain'],
      if (attendee['athleteNotes'] != null)
        'athleteNotes': attendee['athleteNotes'],
      if (attendee['notes'] != null) 'notes': attendee['notes'],
    };

    details.removeWhere((_, value) => value == null);
    return details;
  }

  Map<String, dynamic> withAthleteDrylandActual(
    Map<String, dynamic> attendee, {
    required Map<String, dynamic> actualDrylandDetails,
    int? rpe,
    String? pain,
    String? athleteNotes,
  }) {
    final next = CoachTrainingUtils.normalizeAttendee({
      ...attendee,
      'attendanceStatus': AttendanceStatus.present,
      'isPresent': true,
      'actualDrylandDetails': Map<String, dynamic>.from(actualDrylandDetails),
      if (rpe != null) 'rpe': rpe,
      if (pain != null) 'pain': pain,
      if (athleteNotes != null) 'athleteNotes': athleteNotes,
      'modifiedByAthlete': true,
      'modifiedAt': DateTime.now().toIso8601String(),
    });
    return next;
  }

  List<Map<String, dynamic>>? _blocksFromAny(dynamic value) {
    if (value is Map && value['blocks'] is List) {
      final blocks = (value['blocks'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      return blocks.isEmpty ? null : blocks;
    }
    if (value is List) {
      final blocks = value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      return blocks.isEmpty ? null : blocks;
    }
    return null;
  }

  String _categoryFromEvent(CalendarEvent event, dynamic planned) {
    if (planned is Map && planned['category'] != null) {
      return planned['category'].toString();
    }
    final specialty = event.drylandSpecialty?.toLowerCase().trim();
    switch (specialty) {
      case 'athletic_prep':
      case 'preparazione atletica':
      case 'preparazione':
        return ActivityCategory.athleticPrep;
      case 'strength':
      case 'forza':
        return ActivityCategory.strength;
      case 'plyometrics':
      case 'pliometria':
        return ActivityCategory.plyometrics;
      case 'speed_agility':
      case 'velocita':
      case 'velocita/agilita':
        return ActivityCategory.speedAgility;
      case 'endurance':
      case 'resistenza':
        return ActivityCategory.endurance;
      case 'mobility':
      case 'mobilita':
        return ActivityCategory.mobility;
      case 'core':
        return ActivityCategory.core;
      case 'circuit':
      case 'circuito':
        return ActivityCategory.circuit;
      case 'test':
        return ActivityCategory.test;
      default:
        return ActivityCategory.other;
    }
  }
}
