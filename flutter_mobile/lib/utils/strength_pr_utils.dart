import '../models/models.dart';

DateTime _prLogDate(PRLog log) {
  return DateTime.tryParse(log.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

double currentOneRepMaxForExercise(
  String exerciseId,
  List<PRLog> prLogs, {
  Map<String, double>? profileOneRepMax,
}) {
  final exerciseLogs = prLogs
      .where((log) => log.exerciseId == exerciseId)
      .toList()
    ..sort((a, b) => _prLogDate(b).compareTo(_prLogDate(a)));

  if (exerciseLogs.isNotEmpty) return exerciseLogs.first.weight;
  return profileOneRepMax?[exerciseId] ?? 0.0;
}
