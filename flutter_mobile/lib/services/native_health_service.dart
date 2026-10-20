import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'health_read_guard.dart';

class NativeHealthService {
  static const MethodChannel _channel =
      MethodChannel('com.4athletes.health/hrv');

  /// Recupera i workout normalizzati e puliti (deduplicati e senza outlier)
  static Future<List<Map<String, dynamic>>> getNormalizedWorkouts(
      {int days = 7}) async {
    if (!healthReadAllowed) return [];
    try {
      final List<dynamic>? result = await _channel.invokeMethod(
        'getNormalizedWorkouts',
        {'days': days},
      );
      if (result != null && healthReadAllowed) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get Normalized Workouts: '${e.message}'.");
    }
    return [];
  }
}
