import '../data/exercises.dart';
import '../models/models.dart';

const defaultMaxLoadExerciseIds = [
  'back_squat',
  'deadlift',
  'bp',
  'clean_jerk',
];

ExerciseDef? maxLoadExerciseById(String exerciseId) {
  for (final exercise in exerciseDatabase) {
    if (exercise.id == exerciseId) return exercise;
  }
  return null;
}

String maxLoadExerciseName(String exerciseId) {
  final exercise = maxLoadExerciseById(exerciseId);
  if (exercise != null) return exercise.name;
  return exerciseId
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

List<String> trackedMaxLoadExerciseIds(List<PRLog> logs) {
  final ids = <String>{...defaultMaxLoadExerciseIds};
  final latestByExercise = <String, DateTime>{};
  for (final log in logs) {
    ids.add(log.exerciseId);
    final date =
        DateTime.tryParse(log.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final current = latestByExercise[log.exerciseId];
    if (current == null || date.isAfter(current)) {
      latestByExercise[log.exerciseId] = date;
    }
  }

  final ordered = ids.toList();
  ordered.sort((a, b) {
    final aDate = latestByExercise[a];
    final bDate = latestByExercise[b];
    if (aDate != null && bDate != null) return bDate.compareTo(aDate);
    if (aDate != null) return -1;
    if (bDate != null) return 1;
    final aDefault = defaultMaxLoadExerciseIds.indexOf(a);
    final bDefault = defaultMaxLoadExerciseIds.indexOf(b);
    if (aDefault >= 0 && bDefault >= 0) return aDefault.compareTo(bDefault);
    if (aDefault >= 0) return -1;
    if (bDefault >= 0) return 1;
    return maxLoadExerciseName(a).compareTo(maxLoadExerciseName(b));
  });
  return ordered;
}
