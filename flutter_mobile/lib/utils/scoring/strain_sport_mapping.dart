import 'scoring_types.dart';

StrainSportCategory mapSportTypeToStrainCategory(
  String sportType, {
  Map<String, dynamic>? details,
}) {
  final normalized = sportType.trim().toLowerCase().replaceAll('-', '_');
  final eventType = details?['eventType']?.toString().toLowerCase() ??
      details?['type']?.toString().toLowerCase() ??
      '';

  if (normalized == 'alpine_skiing' ||
      normalized == 'downhill_skiing' ||
      normalized == 'skiing' ||
      normalized == 'snowboarding') {
    return eventType.contains('race') || eventType.contains('gara')
        ? StrainSportCategory.alpineSkiingRace
        : StrainSportCategory.alpineSkiingTraining;
  }

  if (normalized.contains('running') ||
      normalized == 'run' ||
      normalized == 'marathon' ||
      normalized == 'track_field' ||
      normalized == 'track_and_field') {
    return StrainSportCategory.running;
  }

  if (normalized.contains('cycling') ||
      normalized == 'cycling' ||
      normalized == 'biking' ||
      normalized == 'biking_stationary' ||
      normalized == 'spinning') {
    return StrainSportCategory.cycling;
  }

  if (normalized.contains('swimming')) return StrainSportCategory.swimming;

  if (normalized == 'football' ||
      normalized == 'soccer' ||
      normalized == 'calcio') {
    return StrainSportCategory.football;
  }

  if (normalized == 'basketball' ||
      normalized == 'rugby' ||
      normalized == 'american_football' ||
      normalized == 'am_football' ||
      normalized == 'volleyball' ||
      normalized == 'handball' ||
      normalized == 'ice_hockey' ||
      normalized == 'field_hockey' ||
      normalized == 'water_polo' ||
      normalized == 'tennis' ||
      normalized == 'padel' ||
      normalized == 'pickleball' ||
      normalized == 'squash') {
    return StrainSportCategory.teamSport;
  }

  if (normalized == 'weightlifting' ||
      normalized == 'strength' ||
      normalized == 'strength_training' ||
      normalized == 'traditional_strength_training' ||
      normalized == 'functional_strength_training' ||
      normalized == 'powerlifting' ||
      normalized == 'bodybuilding' ||
      normalized == 'dryland' ||
      normalized == 'dryland_strength' ||
      normalized == 'dryland_mixed_circuit' ||
      normalized == 'core' ||
      normalized == 'crossfit' ||
      normalized == 'hiit' ||
      normalized.contains('forza')) {
    return StrainSportCategory.strength;
  }

  if (normalized == 'plyometrics' ||
      normalized == 'dryland_plyometrics' ||
      normalized.contains('pliometr')) {
    return StrainSportCategory.plyometrics;
  }

  if (normalized == 'sprint' ||
      normalized == 'speed_agility' ||
      normalized == 'dryland_speed_agility') {
    return StrainSportCategory.sprint;
  }

  if (normalized == 'mobility' ||
      normalized == 'stretching' ||
      normalized == 'dryland_mobility_core' ||
      normalized == 'yoga' ||
      normalized == 'pilates' ||
      normalized == 'physiotherapy') {
    return StrainSportCategory.mobility;
  }

  if (normalized == 'rowing' ||
      normalized == 'walking' ||
      normalized == 'hiking' ||
      normalized == 'elliptical' ||
      normalized == 'stair_climbing' ||
      normalized == 'cross_country_skiing' ||
      normalized == 'triathlon' ||
      normalized == 'endurance' ||
      normalized == 'dryland_endurance' ||
      normalized == 'athletic_prep') {
    return StrainSportCategory.enduranceGeneric;
  }

  return StrainSportCategory.unknown;
}

bool isEnduranceStrainCategory(StrainSportCategory category) {
  return category == StrainSportCategory.running ||
      category == StrainSportCategory.cycling ||
      category == StrainSportCategory.swimming ||
      category == StrainSportCategory.enduranceGeneric;
}
