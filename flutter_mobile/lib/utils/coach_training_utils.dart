import '../models/models.dart';

class TrainingVolumeSummary {
  final int freeLaps;
  final int freeDirectionChanges;
  final int poleLaps;
  final int polePasses;
  final int trainingLaps;
  final int trainingDirectionChanges;
  final Map<String, int> freeDirectionChangesBySpecialty;
  final Map<String, int> polePassesBySpecialty;
  final Map<String, int> trainingDirectionChangesBySpecialty;

  const TrainingVolumeSummary({
    this.freeLaps = 0,
    this.freeDirectionChanges = 0,
    this.poleLaps = 0,
    this.polePasses = 0,
    this.trainingLaps = 0,
    this.trainingDirectionChanges = 0,
    this.freeDirectionChangesBySpecialty = const {},
    this.polePassesBySpecialty = const {},
    this.trainingDirectionChangesBySpecialty = const {},
  });

  int get totalDirectionChanges =>
      freeDirectionChanges + trainingDirectionChanges;

  int get totalSkiDirectionChanges =>
      freeDirectionChanges + polePasses + trainingDirectionChanges;

  TrainingVolumeSummary operator +(TrainingVolumeSummary other) {
    final freeBySpecialty =
        Map<String, int>.from(freeDirectionChangesBySpecialty);
    for (final entry in other.freeDirectionChangesBySpecialty.entries) {
      freeBySpecialty[entry.key] =
          (freeBySpecialty[entry.key] ?? 0) + entry.value;
    }
    final bySpecialty = Map<String, int>.from(polePassesBySpecialty);
    for (final entry in other.polePassesBySpecialty.entries) {
      bySpecialty[entry.key] = (bySpecialty[entry.key] ?? 0) + entry.value;
    }
    final trainingBySpecialty =
        Map<String, int>.from(trainingDirectionChangesBySpecialty);
    for (final entry in other.trainingDirectionChangesBySpecialty.entries) {
      trainingBySpecialty[entry.key] =
          (trainingBySpecialty[entry.key] ?? 0) + entry.value;
    }
    return TrainingVolumeSummary(
      freeLaps: freeLaps + other.freeLaps,
      freeDirectionChanges: freeDirectionChanges + other.freeDirectionChanges,
      poleLaps: poleLaps + other.poleLaps,
      polePasses: polePasses + other.polePasses,
      trainingLaps: trainingLaps + other.trainingLaps,
      trainingDirectionChanges:
          trainingDirectionChanges + other.trainingDirectionChanges,
      freeDirectionChangesBySpecialty: freeBySpecialty,
      polePassesBySpecialty: bySpecialty,
      trainingDirectionChangesBySpecialty: trainingBySpecialty,
    );
  }

  Map<String, dynamic> toJson() => {
        'freeLaps': freeLaps,
        'freeDirectionChanges': freeDirectionChanges,
        'poleLaps': poleLaps,
        'polePasses': polePasses,
        'trainingLaps': trainingLaps,
        'trainingDirectionChanges': trainingDirectionChanges,
        'totalDirectionChanges': totalDirectionChanges,
        'totalSkiDirectionChanges': totalSkiDirectionChanges,
        'freeDirectionChangesBySpecialty': freeDirectionChangesBySpecialty,
        'polePassesBySpecialty': polePassesBySpecialty,
        'trainingDirectionChangesBySpecialty':
            trainingDirectionChangesBySpecialty,
      };
}

class CoachTrainingUtils {
  static const String statusPlanned = 'planned';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const String attendancePending = 'pending';
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';

  static const List<String> specialties = ['CL', 'SL', 'GS', 'SG', 'DH', 'SX'];

  static List<String> teamIdsForEvent(CalendarEvent event) {
    final details = event.technicalDetails;
    final fromDetails = details == null ? null : details['teamIds'];
    final ids = <String>[];

    void add(String? id) {
      final trimmed = id?.trim();
      if (trimmed != null && trimmed.isNotEmpty && !ids.contains(trimmed)) {
        ids.add(trimmed);
      }
    }

    if (fromDetails is List) {
      for (final value in fromDetails) {
        add(value?.toString());
      }
    } else if (fromDetails is String) {
      for (final value in fromDetails.split(',')) {
        add(value);
      }
    }

    for (final value in event.teamId.split(',')) {
      add(value);
    }

    return ids;
  }

  static String primaryTeamIdForEvent(CalendarEvent event) {
    final ids = teamIdsForEvent(event);
    return ids.isEmpty ? event.teamId : ids.first;
  }

  static Map<String, dynamic> withTeamIds(
    Map<String, dynamic>? details,
    List<String> teamIds,
  ) {
    final next = Map<String, dynamic>.from(details ?? {});
    next['teamIds'] = teamIds.where((id) => id.trim().isNotEmpty).toList();
    return next;
  }

  static String attendeeStatus(Map<String, dynamic> attendee) {
    final explicit = attendee['attendanceStatus']?.toString();
    if (explicit == attendancePresent ||
        explicit == attendanceAbsent ||
        explicit == attendancePending) {
      return explicit!;
    }

    if (attendee['isPresent'] == true) return attendancePresent;
    if (attendee['isPresent'] == false) return attendanceAbsent;
    return attendancePending;
  }

  static bool isAttendeePresent(Map<String, dynamic> attendee) {
    return attendeeStatus(attendee) == attendancePresent;
  }

  static bool isAttendeeAbsent(Map<String, dynamic> attendee) {
    return attendeeStatus(attendee) == attendanceAbsent;
  }

  static Map<String, dynamic> normalizeAttendee(
    Map<String, dynamic> attendee, {
    String? defaultStatus,
  }) {
    final next = Map<String, dynamic>.from(attendee);
    final status = defaultStatus ?? attendeeStatus(next);
    next['attendanceStatus'] = status;
    if (status == attendancePresent) {
      next['isPresent'] = true;
    } else if (status == attendanceAbsent) {
      next['isPresent'] = false;
    } else {
      next['isPresent'] = null;
    }
    return next;
  }

  static String eventSpecialty(CalendarEvent event) {
    return specialtyFromDetails(event.technicalDetails);
  }

  static List<String> specialtiesFromDetails(Map<String, dynamic>? details) {
    final values = <String>[];

    void add(dynamic raw) {
      final text = raw?.toString().trim() ?? '';
      if (text.isEmpty) return;
      final normalized = normalizeSpecialty(text);
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }

    final specialties = details?['specialties'];
    if (specialties is List) {
      for (final specialty in specialties) {
        add(specialty);
      }
    }

    add(details?['specialty']);

    final freeBySpecialty = details?['freeSkiingBySpecialty'];
    if (freeBySpecialty is Map) {
      for (final key in freeBySpecialty.keys) {
        add(key);
      }
    }

    final tracks = details?['tracks'];
    if (tracks is List) {
      for (final track in tracks.whereType<Map>()) {
        add(track['specialty']);
      }
    }

    final trainingBlocks = details?['trainingBlocks'];
    if (trainingBlocks is List) {
      for (final block in trainingBlocks.whereType<Map>()) {
        add(block['specialty']);
      }
    }

    return values.isEmpty ? const ['CL'] : values;
  }

  static String specialtyFromDetails(Map<String, dynamic>? details) {
    final specialties = specialtiesFromDetails(details);
    if (specialties.isNotEmpty) return specialties.first;
    final specialty = details?['specialty']?.toString();
    return normalizeSpecialty(specialty ?? 'CL');
  }

  static String specialtyLabel(String specialty) {
    final normalized = normalizeSpecialty(specialty);
    return normalized == 'SX' ? 'SX Ski Cross' : normalized;
  }

  static String normalizeSpecialty(String value) {
    final upper = value.toUpperCase();
    if (upper.contains('SL') || upper.contains('SLALOM')) return 'SL';
    if (upper.contains('GS') || upper.contains('GIGANTE')) return 'GS';
    if (upper.contains('SG') || upper.contains('SUPER')) return 'SG';
    if (upper.contains('DH') || upper.contains('DISCESA')) return 'DH';
    if (upper.contains('SX') || upper.contains('CROSS')) return 'SX';
    if (upper.contains('CL') || upper.contains('LIBERO')) return 'CL';
    return upper.isEmpty ? 'CL' : upper;
  }

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int asNonNegativeInt(dynamic value, {int fallback = 0}) {
    final parsed = asInt(value, fallback: fallback);
    return parsed < 0 ? 0 : parsed;
  }

  static Map<String, dynamic> freeSkiingFromDetails(
    Map<String, dynamic>? details,
  ) {
    final bySpecialty = freeSkiingBySpecialtyFromDetails(details);
    if (bySpecialty.isNotEmpty) {
      return Map<String, dynamic>.from(bySpecialty.values.first);
    }
    if (details == null) return {};
    return _mapValue(details['freeSkiing']);
  }

  static Map<String, Map<String, dynamic>> freeSkiingBySpecialtyFromDetails(
    Map<String, dynamic>? details,
  ) {
    if (details == null) return {};
    final result = <String, Map<String, dynamic>>{};
    final bySpecialty = details['freeSkiingBySpecialty'];
    if (bySpecialty is Map) {
      for (final entry in bySpecialty.entries) {
        final value = _mapValue(entry.value);
        if (value.isEmpty) continue;
        final specialty = normalizeSpecialty(entry.key.toString());
        result[specialty] = {
          ...value,
          'specialty': specialty,
        };
      }
    }
    if (result.isEmpty) {
      final free = _mapValue(details['freeSkiing']);
      if (free.isNotEmpty) {
        final specialty = specialtyFromDetails(details);
        result[specialty] = {
          ...free,
          'specialty': specialty,
        };
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> tracksFromDetails(
    Map<String, dynamic>? details,
  ) {
    if (details == null) return [];
    return _tracksFromDetails(details);
  }

  static List<Map<String, dynamic>> trainingBlocksFromDetails(
    Map<String, dynamic>? details,
  ) {
    if (details == null) return [];
    return _trainingBlocksFromDetails(details);
  }

  static Map<String, dynamic> chronoFromDetails(
    Map<String, dynamic>? details,
  ) {
    if (details == null) return {};
    return _mapValue(details['chrono']);
  }

  static Map<String, dynamic> buildSessionDetailsForAttendee(
    CalendarEvent event,
    Map<String, dynamic> attendee,
  ) {
    final tech = Map<String, dynamic>.from(event.technicalDetails ?? {});
    final specialties = specialtiesFromDetails(tech);
    final specialty =
        specialties.isEmpty ? eventSpecialty(event) : specialties.first;
    final details = <String, dynamic>{
      'from_calendar': true,
      'specialty': specialty,
      'specialties': specialties,
      'snowCondition': tech['snowCondition'],
      'weatherCondition': tech['weatherCondition'],
      'technicalDetails': tech,
      'athleteModified': attendee['modifiedByAthlete'] == true,
    };

    final freeBySpecialty = freeSkiingBySpecialtyFromDetails(tech);
    if (freeBySpecialty.isNotEmpty) {
      final attendeeFreeLapsBySpecialty =
          _mapValue(attendee['freeLapsBySpecialty']);
      final attendeeFreeChangesBySpecialty =
          _mapValue(attendee['freeChangesBySpecialty']);
      final resolvedFreeBySpecialty = <String, Map<String, dynamic>>{};
      for (final entry in freeBySpecialty.entries) {
        final free = entry.value;
        final useLegacyFallback = freeBySpecialty.length == 1;
        final freeLaps = asInt(
          attendeeFreeLapsBySpecialty[entry.key],
          fallback: asInt(
            useLegacyFallback ? attendee['freeLaps'] : null,
            fallback: asInt(free['laps']),
          ),
        );
        final freeChanges = asInt(
          attendeeFreeChangesBySpecialty[entry.key],
          fallback: asInt(
            useLegacyFallback ? attendee['freeChanges'] : null,
            fallback: asInt(free['changes']),
          ),
        );
        resolvedFreeBySpecialty[entry.key] = {
          ...free,
          'specialty': entry.key,
          'laps': asNonNegativeInt(freeLaps),
          'changes': asNonNegativeInt(freeChanges),
        };
      }
      details['freeSkiingBySpecialty'] = resolvedFreeBySpecialty;
      final firstFree = resolvedFreeBySpecialty.values.first;
      details['freeSkiing'] = firstFree;
      details['freeLaps'] = asNonNegativeInt(firstFree['laps']);
      details['freeChanges'] = asNonNegativeInt(firstFree['changes']);
      details['freeLapsBySpecialty'] = {
        for (final entry in resolvedFreeBySpecialty.entries)
          entry.key: asNonNegativeInt(entry.value['laps']),
      };
      details['freeChangesBySpecialty'] = {
        for (final entry in resolvedFreeBySpecialty.entries)
          entry.key: asNonNegativeInt(entry.value['changes']),
      };
    }

    final tracks = _buildTracks(tech, attendee);
    if (tracks.isNotEmpty) {
      details['tracks'] = tracks;
      details['gatedSkiing'] = {
        'laps': tracks.fold<int>(
          0,
          (sum, track) => sum + asNonNegativeInt(track['laps']),
        ),
        'changes': tracks.fold<int>(
          0,
          (sum, track) =>
              sum +
              asNonNegativeInt(
                track['gates'],
                fallback: asNonNegativeInt(track['changes']),
              ),
        ),
      };
      details['laps'] = asNonNegativeInt(tracks.first['laps']);
    }

    final trainingBlocks = _buildTrainingBlocks(tech, attendee);
    if (trainingBlocks.isNotEmpty) {
      details['trainingBlocks'] = trainingBlocks;
      details['trainingLaps'] = trainingBlocks.fold<int>(
        0,
        (sum, block) => sum + asNonNegativeInt(block['laps']),
      );
    }

    final chrono = _mapValue(tech['chrono']);
    if (chrono.isNotEmpty) details['chrono'] = chrono;

    for (final key in ['rpe', 'pain', 'athleteNotes', 'chronoNotes']) {
      if (attendee[key] != null && attendee[key].toString().isNotEmpty) {
        details[key] = attendee[key];
      }
    }

    final summary = volumeFromDetails(details);
    details['volumeSummary'] = summary.toJson();
    return details;
  }

  static TrainingVolumeSummary volumeFromEventAttendee(
    CalendarEvent event,
    Map<String, dynamic> attendee,
  ) {
    return volumeFromDetails(buildSessionDetailsForAttendee(event, attendee));
  }

  static TrainingVolumeSummary volumeFromDetails(
    Map<String, dynamic>? details,
  ) {
    if (details == null) return const TrainingVolumeSummary();
    final specialty = specialtyFromDetails(details);

    int freeLaps = 0;
    int freeDirectionChanges = 0;
    final freeDirectionChangesBySpecialty = <String, int>{};
    final freeBySpecialty = freeSkiingBySpecialtyFromDetails(details);
    if (freeBySpecialty.isNotEmpty) {
      for (final entry in freeBySpecialty.entries) {
        final free = entry.value;
        final useLegacyFallback = freeBySpecialty.length == 1;
        final laps = asNonNegativeInt(
          useLegacyFallback ? details['freeLaps'] : free['laps'],
          fallback: asNonNegativeInt(free['laps']),
        );
        final changes = asNonNegativeInt(free['changes']);
        final total = laps * changes;
        freeLaps += laps;
        freeDirectionChanges += total;
        if (total > 0) {
          freeDirectionChangesBySpecialty[entry.key] =
              (freeDirectionChangesBySpecialty[entry.key] ?? 0) + total;
        }
      }
    }

    int poleLaps = 0;
    int polePasses = 0;
    final polePassesBySpecialty = <String, int>{};
    final tracks = _tracksFromDetails(details);
    if (tracks.isNotEmpty) {
      for (final track in tracks) {
        final laps = asNonNegativeInt(track['laps']);
        final gates = asNonNegativeInt(
          track['gates'],
          fallback: asNonNegativeInt(track['changes']),
        );
        final total = laps * gates;
        final trackSpecialty = _specialtyForBlock(track, specialty);
        poleLaps += laps;
        polePasses += total;
        if (total > 0) {
          polePassesBySpecialty[trackSpecialty] =
              (polePassesBySpecialty[trackSpecialty] ?? 0) + total;
        }
      }
    } else {
      final gated = _mapValue(details['gatedSkiing']);
      if (gated.isNotEmpty) {
        poleLaps = asNonNegativeInt(
          details['laps'],
          fallback: asNonNegativeInt(gated['laps']),
        );
        final gates = asNonNegativeInt(
          gated['gates'],
          fallback: asNonNegativeInt(gated['changes']),
        );
        polePasses = poleLaps * gates;
        if (polePasses > 0) {
          polePassesBySpecialty[specialty] = polePasses;
        }
      }
    }

    int trainingLaps = 0;
    int trainingDirectionChanges = 0;
    final trainingDirectionChangesBySpecialty = <String, int>{};
    final trainingBlocks = _trainingBlocksFromDetails(details);
    for (final block in trainingBlocks) {
      final laps = asNonNegativeInt(block['laps']);
      final references = asNonNegativeInt(
        block['references'],
        fallback: asNonNegativeInt(block['changes']),
      );
      final total = laps * references;
      final blockSpecialty = _specialtyForBlock(block, specialty);
      trainingLaps += laps;
      trainingDirectionChanges += total;
      if (total > 0) {
        trainingDirectionChangesBySpecialty[blockSpecialty] =
            (trainingDirectionChangesBySpecialty[blockSpecialty] ?? 0) + total;
      }
    }

    return TrainingVolumeSummary(
      freeLaps: freeLaps,
      freeDirectionChanges: freeDirectionChanges,
      poleLaps: poleLaps,
      polePasses: polePasses,
      trainingLaps: trainingLaps,
      trainingDirectionChanges: trainingDirectionChanges,
      freeDirectionChangesBySpecialty: freeDirectionChangesBySpecialty,
      polePassesBySpecialty: polePassesBySpecialty,
      trainingDirectionChangesBySpecialty: trainingDirectionChangesBySpecialty,
    );
  }

  static List<Map<String, dynamic>> _buildTracks(
    Map<String, dynamic> tech,
    Map<String, dynamic> attendee,
  ) {
    final baseTracks = _tracksFromDetails(tech);
    final trackLaps = _mapValue(attendee['trackLaps']);
    final trackGates = _mapValue(attendee['trackGates']);
    if (baseTracks.isEmpty) {
      final gated = _mapValue(tech['gatedSkiing']);
      if (gated.isEmpty) return [];
      final gates = asNonNegativeInt(
        trackGates['track_1'],
        fallback: asNonNegativeInt(
          attendee['gates'],
          fallback: asNonNegativeInt(
            gated['gates'],
            fallback: asNonNegativeInt(gated['changes']),
          ),
        ),
      );
      return [
        {
          'id': 'track_1',
          'name': 'Tracciato 1',
          'laps': asNonNegativeInt(
            attendee['laps'],
            fallback: asNonNegativeInt(gated['laps']),
          ),
          'gates': gates,
          'changes': gates,
        }
      ];
    }

    return baseTracks.map((track) {
      final id = track['id']?.toString() ?? 'track_1';
      final gates = asNonNegativeInt(
        trackGates[id],
        fallback: asNonNegativeInt(
          track['gates'],
          fallback: asNonNegativeInt(track['changes']),
        ),
      );
      return {
        ...track,
        'laps': asNonNegativeInt(
          trackLaps[id],
          fallback: asNonNegativeInt(track['laps']),
        ),
        'gates': gates,
        'changes': gates,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _buildTrainingBlocks(
    Map<String, dynamic> tech,
    Map<String, dynamic> attendee,
  ) {
    final blocks = _trainingBlocksFromDetails(tech);
    final blockLaps = _mapValue(attendee['trainingBlockLaps']);
    final blockReferences = _mapValue(attendee['trainingBlockReferences']);
    return blocks.map((block) {
      final id = block['id']?.toString() ?? 'training_1';
      final references = asNonNegativeInt(
        blockReferences[id],
        fallback: asNonNegativeInt(
          block['references'],
          fallback: asNonNegativeInt(block['changes']),
        ),
      );
      return {
        ...block,
        'laps': asNonNegativeInt(
          blockLaps[id],
          fallback: asNonNegativeInt(block['laps']),
        ),
        'references': references,
        'changes': references,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _tracksFromDetails(
    Map<String, dynamic> details,
  ) {
    final tracks = details['tracks'];
    if (tracks is List) {
      return tracks
          .whereType<Map>()
          .map((track) => Map<String, dynamic>.from(track))
          .toList();
    }
    return [];
  }

  static List<Map<String, dynamic>> _trainingBlocksFromDetails(
    Map<String, dynamic> details,
  ) {
    final blocks = details['trainingBlocks'];
    if (blocks is List) {
      return blocks
          .whereType<Map>()
          .map((block) => Map<String, dynamic>.from(block))
          .toList();
    }
    final addestramento = _mapValue(details['addestramento']);
    if (addestramento.isNotEmpty) {
      return [
        {
          'id': 'training_1',
          'name': 'Addestramento',
          'laps': addestramento['laps'],
          'references': addestramento['references'] ?? addestramento['changes'],
        }
      ];
    }
    return [];
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String _specialtyForBlock(
    Map<String, dynamic> block,
    String fallback,
  ) {
    final raw = block['specialty']?.toString();
    if (raw == null || raw.trim().isEmpty) return fallback;
    return normalizeSpecialty(raw);
  }
}
