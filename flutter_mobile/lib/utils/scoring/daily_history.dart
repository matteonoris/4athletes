import 'scoring_types.dart';

// Date-only UTC arithmetic avoids DST and device-local timezone drift.
DateTime? dailyHistoryDate(String value) {
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().split('T').first != value) {
    return null;
  }
  return parsed;
}

HistoricalDailyData previousDailyHistory(
  HistoricalDailyData history, {
  required String beforeDate,
  required int windowDays,
}) {
  final end = dailyHistoryDate(beforeDate);
  if (end == null || windowDays <= 0) return [];
  final start = end.subtract(Duration(days: windowDays));
  final byDate = <String, DailyWearableData>{};
  for (final day in history) {
    final date = dailyHistoryDate(day.date);
    if (date == null || date.isBefore(start) || !date.isBefore(end)) continue;
    // Last observation of a date replaces an earlier revision.
    byDate[day.date] = day;
  }
  return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

String? dayAfterLatestHistoryDate(HistoricalDailyData history) {
  final dates = history
      .map((day) => dailyHistoryDate(day.date))
      .whereType<DateTime>()
      .toList()
    ..sort();
  if (dates.isEmpty) return null;
  return dates.last
      .add(const Duration(days: 1))
      .toIso8601String()
      .split('T')
      .first;
}
