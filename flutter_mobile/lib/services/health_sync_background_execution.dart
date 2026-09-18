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
