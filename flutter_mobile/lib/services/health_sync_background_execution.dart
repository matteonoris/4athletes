import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps an already-started foreground refresh alive for a limited time.
/// This is not a scheduler and cannot wake a terminated application.
class HealthSyncBackgroundExecution {
  static const _channel = MethodChannel('com.4athletes.health/execution');
  static bool get isForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> begin() => _invoke('begin');
  static Future<void> end() => _invoke('end');

  /// Handles both a running Activity and a launch from the progress notification.
  /// Native code retains the intent until it is consumed, including while Dart
  /// is still starting. Both paths consume it once before forwarding the tap.
  static Future<void> initializeNotificationTapHandling(
      VoidCallback onTap) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    Future<void> consumeTap() async {
      try {
        if (await _channel
                .invokeMethod<bool>('consumeHealthScoreNotificationTap') ==
            true) {
          onTap();
        }
      } on MissingPluginException {
        // An older native binary can still complete the refresh.
      } on PlatformException catch (e) {
        debugPrint('Health notification tap unavailable: ${e.code}');
      }
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'healthScoreNotificationTapped') await consumeTap();
    });
    await consumeTap();
  }

  static Future<void> _invoke(String method) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Desktop/tests and an older native binary still support in-app refresh.
    } on PlatformException catch (e) {
      debugPrint('Health background execution $method unavailable: ${e.code}');
    }
  }
}
