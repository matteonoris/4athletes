import 'package:flutter/services.dart';

class HapticHelper {
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> success() async {
    // There is no success haptic in basic HapticFeedback, 
    // but we can use light/medium/heavy or custom patterns if needed.
    // For now, let's just use medium.
    await HapticFeedback.mediumImpact();
  }
}
