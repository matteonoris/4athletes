import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/email_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final brightness in Brightness.values) {
    Future<void> open(WidgetTester tester,
        Future<void> Function(String, String) signIn) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EmailLoginScreen(onSignIn: signIn),
                    )),
                    child: const Text('Apri accesso'),
                  ),
                )),
      ));
      await tester.tap(find.text('Apri accesso'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('email-login-email')),
          '  REVIEW@EXAMPLE.INVALID  ');
      await tester.enterText(find.byKey(const Key('email-login-password')),
          ' password with spaces ');
      await tester.ensureVisible(find.text('Accedi'));
    }

    testWidgets('validates input before sending ($brightness)', (tester) async {
      var calls = 0;
      await open(tester, (_, __) async => calls++);
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Inserisci un indirizzo email valido.'), findsOneWidget);
      expect(find.text('Inserisci la password.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('password visibility preserves input ($brightness)',
        (tester) async {
      await open(tester, (_, __) async {});
      await fill(tester);
      final field = find.byKey(const Key('email-login-password'));
      expect(tester.widget<TextFormField>(field).controller!.text,
          ' password with spaces ');
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: field, matching: find.byType(EditableText)))
              .obscureText,
          isTrue);
      await tester.tap(find.byTooltip('Mostra password'));
      await tester.pump();
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: field, matching: find.byType(EditableText)))
              .obscureText,
          isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one request, waits, then closes on success ($brightness)',
        (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(tester, (email, password) {
        calls++;
        expect(email, 'review@example.invalid');
        expect(password, ' password with spaces ');
        return pending.future;
      });
      await fill(tester);
      await tester.tap(find.text('Accedi'));
      await tester.pump();
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Apri accesso'), findsOneWidget);
      expect(find.text('Bentornato'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('safe error and retry after failure ($brightness)',
        (tester) async {
      var calls = 0;
      await open(tester, (_, __) async {
        calls++;
        throw const AuthException('Server detail must not be displayed',
            code: 'invalid_credentials');
      });
      await fill(tester);
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(find.text('Email o password non corrette.'), findsOneWidget);
      expect(find.textContaining('Server detail'), findsNothing);
      await tester.ensureVisible(find.text('Accedi'));
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
