import 'package:flutter/material.dart';

import '../models/training_activity_models.dart';

class DrylandPrepTypeOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String category;
  final String sportType;
  final Set<String> exerciseFilters;

  const DrylandPrepTypeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.category,
    required this.sportType,
    this.exerciseFilters = const {},
  });

  bool get isMixed => id == DrylandPrepType.mixedCircuit;
  bool get isEndurance => id == DrylandPrepType.endurance;
}

class DrylandPrepTypes {
  static const List<DrylandPrepTypeOption> options = [
    DrylandPrepTypeOption(
      id: DrylandPrepType.strength,
      title: 'Forza',
      subtitle: 'Palestra, kg, reps, RPE',
      icon: Icons.fitness_center,
      color: Color(0xFFFF8A3D),
      category: ActivityCategory.strength,
      sportType: 'dryland_strength',
      exerciseFilters: {ActivityCategory.strength},
    ),
    DrylandPrepTypeOption(
      id: DrylandPrepType.plyometrics,
      title: 'Pliometria',
      subtitle: 'Balzi, contatti, reattivita',
      icon: Icons.bolt,
      color: Color(0xFFFFC857),
      category: ActivityCategory.plyometrics,
      sportType: 'dryland_plyometrics',
      exerciseFilters: {ActivityCategory.plyometrics},
    ),
    DrylandPrepTypeOption(
      id: DrylandPrepType.speedAgility,
      title: 'Velocita / Agilita',
      subtitle: 'Sprint, cambi, ostacoli',
      icon: Icons.speed,
      color: Color(0xFF43D9B8),
      category: ActivityCategory.speedAgility,
      sportType: 'dryland_speed_agility',
      exerciseFilters: {ActivityCategory.speedAgility},
    ),
    DrylandPrepTypeOption(
      id: DrylandPrepType.endurance,
      title: 'Resistenza',
      subtitle: 'Corsa, cardio, zone',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFF4A90E2),
      category: ActivityCategory.endurance,
      sportType: 'dryland_endurance',
    ),
    DrylandPrepTypeOption(
      id: DrylandPrepType.mobilityCore,
      title: 'Mobilita / Core',
      subtitle: 'Stabilita, controllo, ROM',
      icon: Icons.self_improvement,
      color: Color(0xFF7DD56F),
      category: ActivityCategory.mobility,
      sportType: 'dryland_mobility_core',
      exerciseFilters: {ActivityCategory.mobility, ActivityCategory.core},
    ),
    DrylandPrepTypeOption(
      id: DrylandPrepType.mixedCircuit,
      title: 'Misto / Circuito',
      subtitle: 'Blocchi combinati',
      icon: Icons.loop,
      color: Color(0xFFEB6D8C),
      category: ActivityCategory.athleticPrep,
      sportType: 'dryland_mixed_circuit',
    ),
  ];

  static DrylandPrepTypeOption byId(String? id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => options.first,
    );
  }

  static DrylandPrepTypeOption? maybeById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  static DrylandPrepTypeOption? fromSportType(String? sportType) {
    if (sportType == null || sportType.isEmpty) return null;
    final normalized = sportType.replaceAll('-', '_');
    for (final option in options) {
      if (option.sportType == normalized || option.id == normalized) {
        return option;
      }
    }
    if (normalized == 'athletic_prep') {
      return byId(DrylandPrepType.mixedCircuit);
    }
    return null;
  }

  static DrylandPrepTypeOption fromCategory(String category) {
    switch (category) {
      case ActivityCategory.strength:
        return byId(DrylandPrepType.strength);
      case ActivityCategory.plyometrics:
        return byId(DrylandPrepType.plyometrics);
      case ActivityCategory.speedAgility:
        return byId(DrylandPrepType.speedAgility);
      case ActivityCategory.endurance:
        return byId(DrylandPrepType.endurance);
      case ActivityCategory.mobility:
      case ActivityCategory.core:
        return byId(DrylandPrepType.mobilityCore);
      case ActivityCategory.circuit:
      case ActivityCategory.athleticPrep:
      default:
        return byId(DrylandPrepType.mixedCircuit);
    }
  }
}
