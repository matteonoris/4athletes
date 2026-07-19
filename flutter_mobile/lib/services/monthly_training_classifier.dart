import '../data/workout_catalog.dart';
import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import '../models/training_activity_models.dart';

class MonthlyTrainingClassification {
  final String macroId;
  final String detailId;
  final String detailLabel;
  final TrainingActivity? activity;

  const MonthlyTrainingClassification({
    required this.macroId,
    required this.detailId,
    required this.detailLabel,
    this.activity,
  });
}

class MonthlyTrainingClassifier {
  const MonthlyTrainingClassifier();

  MonthlyTrainingClassification classify(TrainingSession session) {
    final sportId =
        session.sportId.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (_isAlpineSkiing(sportId)) {
      return const MonthlyTrainingClassification(
        macroId: MonthlyTrainingMacro.ski,
        detailId: 'alpine_skiing',
        detailLabel: 'Sci alpino',
      );
    }

    final activity = TrainingActivity.fromTrainingSession(session);
    if (_isRecoverySport(sportId)) {
      return MonthlyTrainingClassification(
        macroId: MonthlyTrainingMacro.recoveryOther,
        detailId: sportId.isEmpty ? 'recovery_other' : sportId,
        detailLabel: WorkoutCatalog.displayName(session.sportId),
        activity: activity,
      );
    }

    final definition = WorkoutCatalog.maybeById(sportId);
    if (definition != null) {
      switch (definition.section) {
        case WorkoutCatalogSection.preparation:
          return MonthlyTrainingClassification(
            macroId: MonthlyTrainingMacro.preparation,
            detailId: preparationDetailId(activity),
            detailLabel: preparationLabel(activity),
            activity: activity,
          );
        case WorkoutCatalogSection.sport:
          return MonthlyTrainingClassification(
            macroId: MonthlyTrainingMacro.otherSports,
            detailId: sportId,
            detailLabel: definition.name,
            activity: activity,
          );
        case WorkoutCatalogSection.other:
          return MonthlyTrainingClassification(
            macroId: MonthlyTrainingMacro.recoveryOther,
            detailId: sportId,
            detailLabel: definition.name,
            activity: activity,
          );
      }
    }

    final details = session.details ?? const <String, dynamic>{};
    final isDryland = details['activityDomain']?.toString() == 'dryland' ||
        sportId.startsWith('dryland') ||
        sportId == 'athletic_prep' ||
        activity.prepType != null;
    final isImportedOrExplicitSport =
        details['activityDomain']?.toString() == 'sport' ||
            details['source']?.toString() == 'health_sync' ||
            details['source']?.toString() == ActivitySource.imported;

    if (!isDryland && isImportedOrExplicitSport) {
      return MonthlyTrainingClassification(
        macroId: MonthlyTrainingMacro.otherSports,
        detailId: sportId.isEmpty ? 'other_sport' : sportId,
        detailLabel: WorkoutCatalog.displayName(session.sportId),
        activity: activity,
      );
    }
    if (isDryland || activity.category != ActivityCategory.sport) {
      return MonthlyTrainingClassification(
        macroId: MonthlyTrainingMacro.preparation,
        detailId: preparationDetailId(activity),
        detailLabel: preparationLabel(activity),
        activity: activity,
      );
    }
    return MonthlyTrainingClassification(
      macroId: MonthlyTrainingMacro.otherSports,
      detailId: sportId.isEmpty ? 'other_sport' : sportId,
      detailLabel: WorkoutCatalog.displayName(session.sportId),
      activity: activity,
    );
  }

  String preparationDetailId(TrainingActivity activity) {
    switch (activity.category) {
      case ActivityCategory.strength:
      case ActivityCategory.plyometrics:
      case ActivityCategory.speedAgility:
      case ActivityCategory.endurance:
      case ActivityCategory.mobility:
      case ActivityCategory.circuit:
      case ActivityCategory.core:
      case ActivityCategory.test:
        return activity.prepType ?? activity.category;
      default:
        return activity.prepType ?? 'mixed_preparation';
    }
  }

  String preparationLabel(TrainingActivity activity) {
    switch (preparationDetailId(activity)) {
      case ActivityCategory.strength:
        return 'Forza';
      case ActivityCategory.plyometrics:
        return 'Pliometria';
      case ActivityCategory.speedAgility:
        return 'Velocità e agilità';
      case ActivityCategory.endurance:
        return 'Resistenza';
      case DrylandPrepType.mobilityCore:
      case ActivityCategory.mobility:
      case ActivityCategory.core:
        return 'Mobilità e core';
      case DrylandPrepType.mixedCircuit:
      case ActivityCategory.circuit:
        return 'Circuito / HIIT';
      case ActivityCategory.test:
        return 'Test';
      default:
        return 'Preparazione mista';
    }
  }

  bool _isRecoverySport(String sportId) => const {
        'mobility_recovery',
        'stretching',
        'yoga',
        'pilates',
      }.contains(sportId);

  bool _isAlpineSkiing(String sportId) => const {
        'alpine_skiing',
        'alpine_ski',
        'downhill_skiing',
        'downhill_ski',
        'ski',
        'skiing',
        'snow_sports',
        'snow_sport',
        'snowsports',
      }.contains(sportId);
}
