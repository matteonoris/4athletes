import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/services/health_sync_background_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.4athletes.health/execution');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var pendingTap = false;

  Future<void> notifyTap() async {
    final completed = Completer<void>();
    await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
            const MethodCall('healthScoreNotificationTapped')), (reply) {
      channel.codec.decodeEnvelope(reply!);
      completed.complete();
    });
    await completed.future;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    pendingTap = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeHealthScoreNotificationTap') {
        final tapped = pendingTap;
        pendingTap = false;
        return tapped;
      }
      return null;
    });
  });
  tearDown(() {
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('a progress notification launch is consumed once during startup',
      () async {
    pendingTap = true;
    var opened = 0;
    await HealthSyncBackgroundExecution.initializeNotificationTapHandling(
        () => opened++);
    expect(opened, 1);
    await notifyTap();
    expect(opened, 1);
  });

  test('a progress notification tap reaches an already running app once',
      () async {
    var opened = 0;
    await HealthSyncBackgroundExecution.initializeNotificationTapHandling(
        () => opened++);
    expect(opened, 0);
    pendingTap = true;
    await notifyTap();
    expect(opened, 1);
    await notifyTap();
    expect(opened, 1);
    pendingTap = true;
    await notifyTap();
    expect(opened, 2);
  });

  test('an older native binary still allows initialization', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await HealthSyncBackgroundExecution.initializeNotificationTapHandling(
        () => fail('No native notification tap was received'));
  });
}
