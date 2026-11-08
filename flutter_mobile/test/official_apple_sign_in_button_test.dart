import 'package:flutter/material.dart';
import 'package:flutter_mobile/widgets/official_apple_sign_in_button.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native_apple_button.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    for (final brightness in Brightness.values) {
      testWidgets('native Apple button is usable at $size in $brightness',
          (tester) async {
        mockNativeAppleButton();
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var presses = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OfficialAppleSignInButton(onPressed: () => presses++)
                  ]),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(view.viewType, 'com.4athletes.auth/apple_button');
        expect(view.creationParams, {
          'style': brightness == Brightness.dark ? 'white' : 'black',
        });
        expect(
            tester.getSize(find.byType(UiKitView)), Size(size.width - 48, 56));
        await pressNativeAppleButton(tester);
        expect(presses, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
      'theme change recreates the native button with the matching style',
      (tester) async {
    mockNativeAppleButton();
    Widget build(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: OfficialAppleSignInButton(onPressed: () {})));
    await tester.pumpWidget(build(Brightness.light));
    await tester.pumpAndSettle();
    final lightKey = tester.widget<UiKitView>(find.byType(UiKitView)).key;
    await tester.pumpWidget(build(Brightness.dark));
    await tester.pumpAndSettle();
    final darkView = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(darkView.key, isNot(lightKey));
    expect(darkView.creationParams, {'style': 'white'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
