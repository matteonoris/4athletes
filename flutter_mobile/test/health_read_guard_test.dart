import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/services/health_read_guard.dart';
import 'package:flutter_mobile/services/native_health_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.4athletes.health/hrv');
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('native health reads without a consent scope never reach the device',
      () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return <double>[30];
    });
    expect(await NativeHealthService.getNightlyRRIntervals(), isEmpty);
    expect(await NativeHealthService.getNormalizedWorkouts(), isEmpty);
    expect(calls, 0);
  });

  test('revocation discards native results and stops the next device query',
      () async {
    var allowed = true;
    var calls = 0;
    final pending = Completer<List<double>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) {
      calls++;
      return pending.future;
    });
    final reading = withHealthReadConsent(
        () => allowed, NativeHealthService.getNightlyRRIntervals);
    await Future<void>.delayed(Duration.zero);
    allowed = false;
    pending.complete([1000]);
    expect(await reading, isEmpty);
    expect(
        await withHealthReadConsent(
            () => allowed, NativeHealthService.getNightlyRRIntervals),
        isEmpty);
    expect(calls, 1);
  });

  test('concurrent async jobs preserve separate account guards', () async {
    var firstAllowed = true;
    final wait = Completer<void>();
    final first = withHealthReadConsent(() => firstAllowed, () async {
      await wait.future;
      return healthReadAllowed;
    });
    final second = withHealthReadConsent(() => true, () async {
      firstAllowed = false;
      await Future<void>.delayed(Duration.zero);
      return healthReadAllowed;
    });
    wait.complete();
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(healthReadAllowed, isFalse);
  });
}
