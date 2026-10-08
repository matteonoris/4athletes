import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/screens/account_deletion_screen.dart';
import 'package:flutter_mobile/services/account_deletion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository implements AccountDeletionRepository {
  String? state;
  Object? failure;
  bool loseResponse = false;
  int requests = 0;
  String? receivedReceipt;
  Future<void> Function(String)? beforeRequest;
  @override
  Future<String?> status(String receipt) async => state;
  @override
  Future<String> request(String receipt) async {
    requests++;
    receivedReceipt = receipt;
    await beforeRequest?.call(receipt);
    if (failure != null) throw failure!;
    state = 'pending';
    if (loseResponse) throw StateError('Connection lost after commit');
    return state!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const owner = '11111111-1111-4111-8111-111111111111';
  const peer = '22222222-2222-4222-8222-222222222222';
  Future<AccountDeletionService> service(_Repository repository) async =>
      AccountDeletionService(repository, await SharedPreferences.getInstance());

  test('persists receipt before request and reconciles a lost response',
      () async {
    final repository = _Repository()..loseResponse = true;
    final deletion = await service(repository);
    repository.beforeRequest = (receipt) async {
      expect(deletion.receipt, receipt);
      expect(deletion.owner, owner);
      expect(receipt, matches(RegExp(r'^[a-f0-9]{64}$')));
    };
    expect(await deletion.request(owner), 'pending');
    expect(deletion.accepted, isTrue);
    expect(await deletion.request(owner), 'pending');
    expect(repository.requests, 1);
    expect(await (await service(repository)).status(), 'pending');
  });
  test('recent login rejection does not claim server acceptance', () async {
    final repository = _Repository()
      ..failure = const PostgrestException(
          message: 'Accedi di nuovo',
          code: '42501',
          hint: 'recent_login_required');
    final deletion = await service(repository);
    await expectLater(
        deletion.request(owner), throwsA(isA<RecentLoginRequired>()));
    expect(deletion.accepted, isFalse);
    expect(await deletion.status(), isNull);
  });
  test('retry after a restart reuses the same unconfirmed receipt', () async {
    final repository = _Repository()
      ..failure = StateError('Network unavailable');
    final first = await service(repository);
    await expectLater(first.request(owner), throwsStateError);
    final receipt = first.receipt;
    repository.failure = null;
    final restarted = await service(repository);
    expect(await restarted.request(owner), 'pending');
    expect(repository.receivedReceipt, receipt);
  });
  test('local erase preserves another account, theme and status receipt',
      () async {
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'isLoggedIn': true,
      'workoutTemplates': 'personal',
      'health_sync_v13_health_units_${owner}_2026-10-08': 'health',
      'health_sync_v13_health_units_${peer}_2026-10-08': 'peer health',
      'health_sync_v12_2026-10-08': 'legacy health',
      'health_consent_pending_revocation_$owner': true,
      'healthAccessEnabled_$owner': true,
      'workout_draft_v4_$owner': 'personal draft',
      'workout_draft_v4_$peer': 'peer draft',
      AccountDeletionService.receiptKey: 'a' * 64,
    });
    final prefs = await SharedPreferences.getInstance();
    await clearDeletedAccountPreferences(prefs, owner);
    expect(prefs.getKeys(), {
      'themeMode',
      'health_sync_v13_health_units_${peer}_2026-10-08',
      'workout_draft_v4_$peer',
      AccountDeletionService.receiptKey,
    });
    await expectLater(
        clearDeletedAccountPreferences(prefs, ''), throwsArgumentError);
  });
  test('forgetting the receipt also clears its acceptance marker', () async {
    final deletion = await service(_Repository());
    await deletion.request(owner);
    await deletion.forgetReceipt();
    expect(deletion.receipt, isNull);
    expect(deletion.owner, isNull);
    expect(deletion.accepted, isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets('confirmation and verified completion in $brightness',
        (tester) async {
      final repository = _Repository();
      final deletion = await service(repository);
      var accepted = 0;
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: AccountDeletionScreen(
              service: deletion,
              userId: owner,
              onAccepted: () async => accepted++,
              onLogin: () async {},
              onClose: () {})));
      await tester.pumpAndSettle();
      final confirm = find.text('Elimina definitivamente');
      await tester.scrollUntilVisible(confirm, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Elimina definitivamente'))
              .onPressed,
          isNull);
      await tester.enterText(find.byType(TextField), 'ELIMINA');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.requests, 1);
      expect(accepted, 1);
      // The confirmation button was below the fold. Bring the status heading
      // back into the lazy ListView viewport before checking its visible text.
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Eliminazione in corso'), findsOneWidget);
      expect(find.text('Account eliminato'), findsNothing);
      repository.state = 'completed';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Account eliminato'), findsOneWidget);
      expect(accepted, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('requires re-login without deleting or claiming success',
      (tester) async {
    final repository = _Repository()
      ..failure = const PostgrestException(
          message: 'Accedi di nuovo',
          code: '42501',
          hint: 'recent_login_required');
    final deletion = await service(repository);
    var accepted = 0;
    var login = 0;
    await tester.pumpWidget(MaterialApp(
        home: AccountDeletionScreen(
            service: deletion,
            userId: owner,
            onAccepted: () async => accepted++,
            onLogin: () async => login++,
            onClose: () {})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ELIMINA');
    await tester.ensureVisible(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Accedi di nuovo'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accedi di nuovo'));
    expect(login, 1);
    expect(accepted, 0);
    expect(find.text('Account eliminato'), findsNothing);
  });
}
