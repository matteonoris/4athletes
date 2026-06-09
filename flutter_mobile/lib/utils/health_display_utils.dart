import '../models/models.dart';

const String missingValue = '\u2014';

class DailyChartPoint {
  final DateTime date;
  final double? value;
  final double? baseline;

  const DailyChartPoint({
    required this.date,
    required this.value,
    this.baseline,
  });
}

String readinessStatus(double? recoveryScore) {
  if (recoveryScore == null) return 'Dato non disponibile';
  if (recoveryScore >= 85) return 'Molto alto';
  if (recoveryScore >= 70) return 'Buono';
  if (recoveryScore >= 55) return 'Moderato';
  if (recoveryScore >= 40) return 'Basso';
  return 'Molto basso';
}

String formatMinutesAsHours(num? minutes) {
  if (minutes == null || !minutes.isFinite) return missingValue;
  final rounded = minutes.round();
  final sign = rounded < 0 ? '-' : '';
  final abs = rounded.abs();
  final hours = abs ~/ 60;
  final mins = abs % 60;
  if (hours == 0) return '$sign${mins}m';
  if (mins == 0) return '$sign${hours}h';
  return '$sign${hours}h ${mins}m';
}

String formatPercent(num? value, {int decimals = 0}) {
  if (value == null || !value.isFinite) return missingValue;
  return '${value.toStringAsFixed(decimals)}%';
}

String formatSigned(num? value, String unit, {int decimals = 0}) {
  if (value == null || !value.isFinite) return missingValue;
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)} $unit';
}

double? rollingBaseline(
  List<BodyMetricLog> logs,
  String type,
  DateTime beforeDate, {
  int days = 30,
}) {
  final start = DateTime(beforeDate.year, beforeDate.month, beforeDate.day)
      .subtract(Duration(days: days));
  final values = logs
      .where((log) {
        if (log.type != type) return false;
        final date = DateTime.tryParse(log.date);
        if (date == null) return false;
        return !date.isBefore(start) && date.isBefore(beforeDate);
      })
      .map((log) => log.value)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

List<DailyChartPoint> buildDailySeries({
  required List<BodyMetricLog> logs,
  required String type,
  required DateTime endDate,
  required int days,
  bool includeRollingBaseline = false,
}) {
  final byDate = <String, double>{};
  for (final log in logs.where((log) => log.type == type)) {
    byDate[log.date] = log.value;
  }

  final end = DateTime(endDate.year, endDate.month, endDate.day);
  return List<DailyChartPoint>.generate(days, (index) {
    final date = end.subtract(Duration(days: days - index - 1));
    final key = date.toIso8601String().split('T').first;
    return DailyChartPoint(
      date: date,
      value: byDate[key],
      baseline: includeRollingBaseline
          ? rollingBaseline(logs, type, date, days: 30)
          : null,
    );
  });
}

bool shouldShowHeightChart(UserProfile? profile) {
  return profile == null || profile.age < 18;
}
