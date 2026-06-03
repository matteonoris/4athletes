class TimeUtils {
  static int parseDurationToMinutes(dynamic duration) {
    if (duration == null) return 0;
    String durStr = duration.toString().trim();
    if (durStr.isEmpty) return 0;

    try {
      if (durStr.contains('h')) {
        final parts = durStr.split('h');
        int h = int.tryParse(parts[0].trim()) ?? 0;
        int m = 0;
        if (parts.length > 1 && parts[1].contains('m')) {
          m = int.tryParse(parts[1].replaceAll('m', '').trim()) ?? 0;
        }
        return (h * 60) + m;
      } else if (durStr.contains(':')) {
        final parts = durStr.split(':');
        if (parts.length >= 2) {
          // Usually HH:MM:SS or HH:MM
          return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        }
      } else if (durStr.toLowerCase().contains('min') || durStr.toLowerCase().contains('m')) {
        String numStr = durStr.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(numStr) ?? 0;
      } else {
        // Assume integer minutes
        String numStr = durStr.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(numStr) ?? 0;
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  static double parseDurationToHours(dynamic duration) {
    return parseDurationToMinutes(duration) / 60.0;
  }

  static String formatDuration(dynamic duration) {
    int mins = parseDurationToMinutes(duration);
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }
}
