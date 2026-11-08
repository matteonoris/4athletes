import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_mobile/widgets/official_apple_sign_in_button.dart';
import 'package:flutter_test/flutter_test.dart';

int? _latestViewId;

void mockNativeAppleButton() {
  _latestViewId = null;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform_views,
      (call) async {
    if (call.method == 'create') {
      final args = call.arguments as Map;
      if (args['viewType'] == 'com.4athletes.auth/apple_button') {
        _latestViewId = args['id'] as int;
      }
    }
    return null;
  });
  addTearDown(() =>
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
}

Future<void> pressNativeAppleButton(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(OfficialAppleSignInButton));
  await tester.pumpAndSettle();
  expect(_latestViewId, isNotNull);
  final reply = Completer<void>();
  tester.binding.channelBuffers.push(
    'com.4athletes.auth/apple_button/$_latestViewId',
    const StandardMethodCodec().encodeMethodCall(const MethodCall('pressed')),
    (_) => reply.complete(),
  );
  await tester.pump();
  await reply.future;
}
