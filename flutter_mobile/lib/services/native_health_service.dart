import 'package:flutter/services.dart';

class NativeHealthService {
  static const MethodChannel _channel = MethodChannel('com.4athletes.health/hrv');

  /// Recupera gli intervalli RR raw dalla mezzanotte alle 8:00
  static Future<List<double>> getNightlyRRIntervals() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getRRIntervals');
      if (result != null) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
    } on PlatformException catch (e) {
      print("Failed to get RR Intervals: '${e.message}'.");
    }
    return [];
  }
}
