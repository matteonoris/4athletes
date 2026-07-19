import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import '../models/training_activity_models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/time_utils.dart';
import 'training_activity_service.dart';
import 'monthly_training_classifier.dart';

class AthleteRecapMacro {
  static const ski = MonthlyTrainingMacro.ski;
  static const preparation = MonthlyTrainingMacro.preparation;
  static const otherSports = MonthlyTrainingMacro.otherSports;
  static const recoveryOther = MonthlyTrainingMacro.recoveryOther;

  static const ordered = MonthlyTrainingMacro.ordered;

  static String label(String id) => MonthlyTrainingMacro.label(id);
}

class AthleteMonthlyRecapBucket {
  final String id;
  final String label;
  final double minutes;
  final double sessionCount;
  final Map<String, AthleteMonthlyRecapBucket> details;

  const AthleteMonthlyRecapBucket({
    required this.id,
    required this.label,
    required this.minutes,
    required this.sessionCount,
    this.details = const {},
  });

  double percentageOf(double totalMinutes) =>
      totalMinutes <= 0 ? 0 : (minutes / totalMinutes) * 100;
}

class AthleteSkiSpecialtyRecap {
  final String id;
  final String label;
  final int sessionCount;
  final int technicalVolume;

  const AthleteSkiSpecialtyRecap({
    required this.id,
    required this.label,
    required this.sessionCount,
    required this.technicalVolume,
  });
}

class AthleteMonthlyRecapPeriod {
  final DateTime month;
  final int? throughDay;
  final double totalMinutes;
  final double sessionCount;
  final double validDurationSessionCount;
  final double incompleteDurationCount;
  final Map<String, AthleteMonthlyRecapBucket> buckets;
  final Map<String, AthleteSkiSpecialtyRecap> skiSpecialties;

  const AthleteMonthlyRecapPeriod({
    required this.month,
    required this.throughDay,
    required this.totalMinutes,
    required this.sessionCount,
    required this.validDurationSessionCount,
    required this.incompleteDurationCount,
    required this.buckets,
    this.skiSpecialties = const {},
  });

  double get averageSessionMinutes => validDurationSessionCount <= 0
      ? 0
      : totalMinutes / validDurationSessionCount;

  AthleteMonthlyRecapBucket bucket(String id) =>
      buckets[id] ??
      AthleteMonthlyRecapBucket(
        id: id,
        label: AthleteRecapMacro.label(id),
        minutes: 0,
        sessionCount: 0,
      );
}

class AthleteMonthlyRecap {
  final DateTime selectedMonth;
  final DateTime earliestMonth;
  final AthleteMonthlyRecapPeriod selected;
  final AthleteMonthlyRecapPeriod? previous;
  final AthleteMonthlyRecapPeriod? average;
  final int averageMonthCount;
  final bool isCurrentMonth;

  const AthleteMonthlyRecap({
    required this.selectedMonth,
    required this.earliestMonth,
    required this.selected,
    required this.previous,
    required this.average,
    required this.averageMonthCount,
    required this.isCurrentMonth,
  });
}

class AthleteMonthlyRecapCalculator {
  const AthleteMonthlyRecapCalculator();

  AthleteMonthlyRecap build({
    required List<TrainingSession> sessions,
    required List<CalendarEvent> coachEvents,
    required DateTime selectedMonth,
    required DateTime now,
    String? athleteId,
    String? athleteEmail,
    String? athleteName,
  }) {
    final normalizedMonth = DateTime(selectedMonth.year, selectedMonth.month);
    final normalizedNow = DateTime(now.year, now.month, now.day);
    final entries = _canonicalEntries(
      sessions: sessions,
      coachEvents: coachEvents,
      athleteId: athleteId,
      athleteEmail: athleteEmail,
      athleteName: athleteName,
    );
    final earliestDate = entries.isEmpty
        ? normalizedMonth
        : entries.map((entry) => entry.date).reduce(
              (a, b) => a.isBefore(b) ? a : b,
            );
    final earliestMonth = DateTime(earliestDate.year, earliestDate.month);
    final isCurrentMonth = normalizedMonth.year == normalizedNow.year &&
        normalizedMonth.month == normalizedNow.month;
    final throughDay = isCurrentMonth ? normalizedNow.day : null;

    final selected = _period(
      entries,
      normalizedMonth,
      throughDay: throughDay,
    );
    final previousMonth = DateTime(
      normalizedMonth.year,
      normalizedMonth.month - 1,
    );
    final previous = _isSameOrAfter(previousMonth, earliestMonth)
        ? _period(entries, previousMonth, throughDay: throughDay)
        : null;

    final averagePeriods = <AthleteMonthlyRecapPeriod>[];
    for (var offset = 1; offset <= 3; offset++) {
      final month = DateTime(
        normalizedMonth.year,
        normalizedMonth.month - offset,
      );
      if (_isSameOrAfter(month, earliestMonth)) {
        averagePeriods.add(_period(entries, month, throughDay: throughDay));
      }
    }

    return AthleteMonthlyRecap(
      selectedMonth: normalizedMonth,
      earliestMonth: earliestMonth,
      selected: selected,
      previous: previous,
      average: averagePeriods.isEmpty
          ? null
          : _averagePeriod(averagePeriods, normalizedMonth),
      averageMonthCount: averagePeriods.length,
      isCurrentMonth: isCurrentMonth,
    );
  }

  List<_RecapEntry> _canonicalEntries({
    required List<TrainingSession> sessions,
    required List<CalendarEvent> coachEvents,
    required String? athleteId,
    required String? athleteEmail,
    required String? athleteName,
  }) {
    final mergedExternalIds = <String>{};
    final mergedSessionIds = <String>{};
    for (final session in sessions) {
      final details = session.details ?? const <String, dynamic>{};
      if (details['workoutSource']?.toString() != 'merged') continue;
      final sourceIds = details['merged_source_workout_ids'];
      if (sourceIds is List) {
        mergedExternalIds.addAll(sourceIds.map((id) => id.toString()));
      }
      final externalLink = details['externalLink'];
      if (externalLink is Map) {
        final sourceSessionId = externalLink['sourceSessionId']?.toString();
        if (sourceSessionId != null && sourceSessionId != session.id) {
          mergedSessionIds.add(sourceSessionId);
        }
      }
    }

    final byId = <String, TrainingSession>{};
    for (final session in sessions) {
      final details = session.details ?? const <String, dynamic>{};
      final isMerged = details['workoutSource']?.toString() == 'merged';
      final externalId = details['external_id']?.toString();
      if (!isMerged &&
          (mergedSessionIds.contains(session.id) ||
              (externalId != null && mergedExternalIds.contains(externalId)))) {
        continue;
      }
      if (!_isCompleted(session)) continue;
      byId.putIfAbsent(session.id, () => session);
    }

    final byEvent = <String, TrainingSession>{};
    final withoutEvent = <TrainingSession>[];
    for (final session in byId.values) {
      final eventId = session.eventId?.trim();
      if (eventId == null || eventId.isEmpty) {
        withoutEvent.add(session);
        continue;
      }
      final existing = byEvent[eventId];
      if (existing == null || _prefer(session, existing)) {
        byEvent[eventId] = session;
      }
    }

    final canonicalSessions = [...withoutEvent, ...byEvent.values];
    final entries = canonicalSessions
        .map((session) {
          final date = _parseDate(session.date);
          return date == null ? null : _RecapEntry(session, date);
        })
        .whereType<_RecapEntry>()
        .toList();
    final linkedEventIds = byEvent.keys.toSet();

    for (final event in coachEvents) {
      if (event.status != CoachTrainingUtils.statusCompleted ||
          linkedEventIds.contains(event.id)) {
        continue;
      }
      final attendee = _matchingAttendee(
        event,
        athleteId: athleteId,
        athleteEmail: athleteEmail,
        athleteName: athleteName,
      );
      if (attendee == null || !_attended(attendee)) continue;
      final fallback = _sessionFromCompletedEvent(event, attendee);
      final date = _parseDate(fallback.date);
      if (date != null) entries.add(_RecapEntry(fallback, date));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  bool _isCompleted(TrainingSession session) {
    final activity = TrainingActivity.fromTrainingSession(session);
    return activity.status != ActivityStatus.planned &&
        activity.status != ActivityStatus.cancelled;
  }

  bool _prefer(TrainingSession candidate, TrainingSession existing) {
    final candidateMerged =
        candidate.details?['workoutSource']?.toString() == 'merged';
    final existingMerged =
        existing.details?['workoutSource']?.toString() == 'merged';
    if (candidateMerged != existingMerged) return candidateMerged;
    return (_durationMinutes(candidate) ?? 0) >
        (_durationMinutes(existing) ?? 0);
  }

  Map<String, dynamic>? _matchingAttendee(
    CalendarEvent event, {
    required String? athleteId,
    required String? athleteEmail,
    required String? athleteName,
  }) {
    final normalizedName = athleteName?.trim();
    for (final attendee in event.attendees ?? const []) {
      final id = attendee['id']?.toString();
      final name = attendee['name']?.toString().trim();
      if ((athleteId != null && id == athleteId) ||
          (athleteEmail != null && id == athleteEmail) ||
          (normalizedName != null &&
              normalizedName.isNotEmpty &&
              name == normalizedName)) {
        return attendee;
      }
    }
    return null;
  }

  bool _attended(Map<String, dynamic> attendee) {
    final status = attendee['attendanceStatus']?.toString().toLowerCase();
    if (status == CoachTrainingUtils.attendanceAbsent ||
        status == CoachTrainingUtils.attendancePending) {
      return false;
    }
    return status == CoachTrainingUtils.attendancePresent ||
        status == 'partial' ||
        attendee['isPresent'] == true;
  }

  TrainingSession _sessionFromCompletedEvent(
    CalendarEvent event,
    Map<String, dynamic> attendee,
  ) {
    final isSki = event.sportCategory == 'ski';
    final details = isSki
        ? CoachTrainingUtils.buildSessionDetailsForAttendee(event, attendee)
        : const TrainingActivityService()
            .buildCoachDrylandSessionDetails(event, attendee);
    final duration = _clockDurationMinutes(event.startTime, event.endTime) ?? 0;
    return TrainingSession(
      id: 'event_${event.id}',
      sportId: isSki
          ? 'alpine_skiing'
          : details['sportType']?.toString() ??
              details['activityCategory']?.toString() ??
              'athletic_prep',
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      duration: duration.toString(),
      effort: CoachTrainingUtils.asInt(attendee['rpe']),
      eventId: event.id,
      details: {
        ...details,
        'source': ActivitySource.coach,
        'status': ActivityStatus.completed,
        'from_calendar': true,
      },
    );
  }

  AthleteMonthlyRecapPeriod _period(
    List<_RecapEntry> entries,
    DateTime month, {
    required int? throughDay,
  }) {
    final period = _MutablePeriod(month, throughDay);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final endDay =
        throughDay == null ? lastDay : throughDay.clamp(1, lastDay).toInt();
    for (final entry in entries) {
      if (entry.date.year != month.year ||
          entry.date.month != month.month ||
          entry.date.day > endDay) {
        continue;
      }
      _addSession(period, entry.session);
    }
    return period.freeze();
  }

  void _addSession(_MutablePeriod period, TrainingSession session) {
    final duration = _durationMinutes(session);
    final classification = _classification(session);
    period.add(
      macroId: classification.macroId,
      detailId: classification.detailId,
      detailLabel: classification.detailLabel,
      minutes: duration?.toDouble() ?? 0,
      hasValidDuration: duration != null && duration > 0,
    );
    if (classification.macroId == AthleteRecapMacro.ski) {
      _addSkiDetails(period, session);
    }
  }

  MonthlyTrainingClassification _classification(TrainingSession session) =>
      const MonthlyTrainingClassifier().classify(session);

  void _addSkiDetails(_MutablePeriod period, TrainingSession session) {
    final details = session.details;
    final specialties = _explicitSkiSpecialties(details);
    final volume = CoachTrainingUtils.volumeFromDetails(details);
    if (specialties.isEmpty) {
      period.addSkiSpecialty(
        'unspecified',
        'Non specificato',
        technicalVolume: volume.totalSkiDirectionChanges,
      );
      return;
    }

    final technicalBySpecialty = <String, int>{};
    void addMap(Map<String, int> values) {
      for (final entry in values.entries) {
        final specialty = CoachTrainingUtils.normalizeSpecialty(entry.key);
        technicalBySpecialty[specialty] =
            (technicalBySpecialty[specialty] ?? 0) + entry.value;
      }
    }

    addMap(volume.freeDirectionChangesBySpecialty);
    addMap(volume.polePassesBySpecialty);
    addMap(volume.trainingDirectionChangesBySpecialty);
    for (final specialty in specialties) {
      period.addSkiSpecialty(
        specialty,
        _specialtyLabel(specialty),
        technicalVolume: technicalBySpecialty[specialty] ?? 0,
      );
    }

    final mappedVolume =
        technicalBySpecialty.values.fold<int>(0, (a, b) => a + b);
    final unassigned = volume.totalSkiDirectionChanges - mappedVolume;
    if (unassigned > 0) {
      if (specialties.length == 1) {
        period.addSkiTechnicalVolume(specialties.single, unassigned);
      } else {
        period.addSkiSpecialty(
          'unspecified',
          'Non specificato',
          technicalVolume: unassigned,
          countSession: false,
        );
      }
    }
  }

  List<String> _explicitSkiSpecialties(Map<String, dynamic>? details) {
    if (details == null || details.isEmpty) return const [];
    final values = <String>[];
    void add(dynamic raw) {
      final text = raw?.toString().trim() ?? '';
      if (text.isEmpty) return;
      final value = CoachTrainingUtils.normalizeSpecialty(text);
      if (CoachTrainingUtils.specialties.contains(value) &&
          !values.contains(value)) {
        values.add(value);
      }
    }

    final explicit = details['specialties'];
    if (explicit is List) {
      for (final value in explicit) {
        add(value);
      }
    }
    add(details['specialty']);
    final free = details['freeSkiingBySpecialty'];
    if (free is Map) {
      for (final key in free.keys) {
        add(key);
      }
    }
    for (final key in ['tracks', 'trainingBlocks']) {
      final blocks = details[key];
      if (blocks is List) {
        for (final block in blocks.whereType<Map>()) {
          add(block['specialty']);
        }
      }
    }
    return values;
  }

  String _specialtyLabel(String id) {
    if (id == 'CL') return 'CL · Sci libero';
    return CoachTrainingUtils.specialtyLabel(id);
  }

  int? _durationMinutes(TrainingSession session) {
    final parsed = TimeUtils.parseDurationToMinutes(session.duration);
    if (parsed > 0) return parsed;
    final details = session.details ?? const <String, dynamic>{};
    final candidates = <dynamic>[
      details['actualDurationMinutes'],
      details['actual'] is Map ? details['actual']['durationMinutes'] : null,
      details['total_duration_minutes'],
      details['active_duration_minutes'],
    ];
    for (final value in candidates) {
      final minutes =
          value is num ? value.round() : int.tryParse(value?.toString() ?? '');
      if (minutes != null && minutes > 0) return minutes;
    }
    return _clockDurationMinutes(session.startTime, session.endTime);
  }

  int? _clockDurationMinutes(String startTime, String endTime) {
    final start = _clockMinutes(startTime);
    final end = _clockMinutes(endTime);
    if (start == null || end == null || start == end) return null;
    var duration = end - start;
    if (duration < 0) duration += 24 * 60;
    return duration > 0 ? duration : null;
  }

  int? _clockMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  AthleteMonthlyRecapPeriod _averagePeriod(
    List<AthleteMonthlyRecapPeriod> periods,
    DateTime selectedMonth,
  ) {
    final divisor = periods.length.toDouble();
    final macroBuckets = <String, AthleteMonthlyRecapBucket>{};
    for (final macroId in AthleteRecapMacro.ordered) {
      final buckets = periods.map((period) => period.bucket(macroId)).toList();
      final detailIds = buckets.expand((bucket) => bucket.details.keys).toSet();
      final details = <String, AthleteMonthlyRecapBucket>{};
      for (final detailId in detailIds) {
        final values = buckets
            .map((bucket) => bucket.details[detailId])
            .whereType<AthleteMonthlyRecapBucket>()
            .toList();
        final label = values.isEmpty ? detailId : values.first.label;
        details[detailId] = AthleteMonthlyRecapBucket(
          id: detailId,
          label: label,
          minutes: values.fold<double>(0, (sum, value) => sum + value.minutes) /
              divisor,
          sessionCount: values.fold<double>(
                0,
                (sum, value) => sum + value.sessionCount,
              ) /
              divisor,
        );
      }
      macroBuckets[macroId] = AthleteMonthlyRecapBucket(
        id: macroId,
        label: AthleteRecapMacro.label(macroId),
        minutes: buckets.fold<double>(0, (sum, value) => sum + value.minutes) /
            divisor,
        sessionCount: buckets.fold<double>(
              0,
              (sum, value) => sum + value.sessionCount,
            ) /
            divisor,
        details: details,
      );
    }
    return AthleteMonthlyRecapPeriod(
      month: selectedMonth,
      throughDay: periods.first.throughDay,
      totalMinutes:
          periods.fold<double>(0, (sum, value) => sum + value.totalMinutes) /
              divisor,
      sessionCount: periods.fold<double>(
            0,
            (sum, value) => sum + value.sessionCount,
          ) /
          divisor,
      validDurationSessionCount: periods.fold<double>(
            0,
            (sum, value) => sum + value.validDurationSessionCount,
          ) /
          divisor,
      incompleteDurationCount: periods.fold<double>(
            0,
            (sum, value) => sum + value.incompleteDurationCount,
          ) /
          divisor,
      buckets: macroBuckets,
    );
  }

  DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  bool _isSameOrAfter(DateTime value, DateTime minimum) =>
      value.year > minimum.year ||
      (value.year == minimum.year && value.month >= minimum.month);
}

class _RecapEntry {
  final TrainingSession session;
  final DateTime date;

  const _RecapEntry(this.session, this.date);
}

class _MutablePeriod {
  final DateTime month;
  final int? throughDay;
  double totalMinutes = 0;
  double sessionCount = 0;
  double validDurationSessionCount = 0;
  double incompleteDurationCount = 0;
  final Map<String, _MutableBucket> buckets = {};
  final Map<String, _MutableSkiSpecialty> skiSpecialties = {};

  _MutablePeriod(this.month, this.throughDay) {
    for (final id in AthleteRecapMacro.ordered) {
      buckets[id] = _MutableBucket(id, AthleteRecapMacro.label(id));
    }
  }

  void add({
    required String macroId,
    required String detailId,
    required String detailLabel,
    required double minutes,
    required bool hasValidDuration,
  }) {
    totalMinutes += minutes;
    sessionCount += 1;
    if (hasValidDuration) {
      validDurationSessionCount += 1;
    } else {
      incompleteDurationCount += 1;
    }
    final bucket = buckets.putIfAbsent(
      macroId,
      () => _MutableBucket(macroId, AthleteRecapMacro.label(macroId)),
    );
    bucket.minutes += minutes;
    bucket.sessionCount += 1;
    final detail = bucket.details.putIfAbsent(
      detailId,
      () => _MutableBucket(detailId, detailLabel),
    );
    detail.minutes += minutes;
    detail.sessionCount += 1;
  }

  void addSkiSpecialty(
    String id,
    String label, {
    required int technicalVolume,
    bool countSession = true,
  }) {
    final specialty = skiSpecialties.putIfAbsent(
      id,
      () => _MutableSkiSpecialty(id, label),
    );
    if (countSession) specialty.sessionCount += 1;
    specialty.technicalVolume += technicalVolume;
  }

  void addSkiTechnicalVolume(String id, int value) {
    skiSpecialties[id]?.technicalVolume += value;
  }

  AthleteMonthlyRecapPeriod freeze() {
    final frozenBuckets = <String, AthleteMonthlyRecapBucket>{};
    for (final entry in buckets.entries) {
      frozenBuckets[entry.key] = entry.value.freeze();
    }
    final orderedSpecialtyIds = [
      'CL',
      'SL',
      'GS',
      'SG',
      'DH',
      'SX',
      ...skiSpecialties.keys.where(
        (id) => !const ['CL', 'SL', 'GS', 'SG', 'DH', 'SX'].contains(id),
      ),
    ];
    final frozenSki = <String, AthleteSkiSpecialtyRecap>{};
    for (final id in orderedSpecialtyIds) {
      final value = skiSpecialties[id];
      if (value != null) frozenSki[id] = value.freeze();
    }
    return AthleteMonthlyRecapPeriod(
      month: month,
      throughDay: throughDay,
      totalMinutes: totalMinutes,
      sessionCount: sessionCount,
      validDurationSessionCount: validDurationSessionCount,
      incompleteDurationCount: incompleteDurationCount,
      buckets: frozenBuckets,
      skiSpecialties: frozenSki,
    );
  }
}

class _MutableBucket {
  final String id;
  final String label;
  double minutes = 0;
  double sessionCount = 0;
  final Map<String, _MutableBucket> details = {};

  _MutableBucket(this.id, this.label);

  AthleteMonthlyRecapBucket freeze() => AthleteMonthlyRecapBucket(
        id: id,
        label: label,
        minutes: minutes,
        sessionCount: sessionCount,
        details: {
          for (final entry in details.entries) entry.key: entry.value.freeze(),
        },
      );
}

class _MutableSkiSpecialty {
  final String id;
  final String label;
  int sessionCount = 0;
  int technicalVolume = 0;

  _MutableSkiSpecialty(this.id, this.label);

  AthleteSkiSpecialtyRecap freeze() => AthleteSkiSpecialtyRecap(
        id: id,
        label: label,
        sessionCount: sessionCount,
        technicalVolume: technicalVolume,
      );
}
