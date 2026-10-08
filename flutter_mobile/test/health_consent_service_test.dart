import 'dart:async';
import 'package:flutter_mobile/services/health_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements HealthConsentRepository {
  final decisions = <String, HealthConsentDecision>{};
  bool offline = false;
  Completer<HealthConsentDecision?>? delayedRead;
  Completer<void>? delayedWrite;
  @override
  Future<HealthConsentDecision?> latest(String owner) async {
    if (offline) throw StateError('offline');
    if (delayedRead != null) return delayedRead!.future;
    return decisions[owner];
  }

  @override
  Future<void> record(String owner, HealthConsentDecision choice) async {
    if (offline) throw StateError('offline');
    if (delayedWrite != null) await delayedWrite!.future;
    decisions[owner] = choice;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy device permission does not constitute app consent', () async {
    SharedPreferences.setMockInitialValues({'health_access_enabled_a': true});
    final service = HealthConsentService(_Repository());
    await service.load('a');
    expect(service.loaded, isTrue);
    expect(service.decision, isNull);
    expect(service.granted, isFalse);
  });

  test('grant and refusal are persisted and restored per account', () async {
    final repository = _Repository();
    final service = HealthConsentService(repository);
    await service.load('a');
    await service.choose('a', HealthConsentDecision.granted);
    expect(service.granted, isTrue);
    await service.load('b');
    expect(service.granted, isFalse);
    await service.choose('b', HealthConsentDecision.declined);
    final restored = HealthConsentService(repository);
    await restored.load('b');
    expect(restored.decision, HealthConsentDecision.declined);
    await restored.load('a');
    expect(restored.granted, isTrue);
  });

  test('failed grant never activates imports or records a choice locally',
      () async {
    final repository = _Repository();
    final service = HealthConsentService(repository);
    await service.load('a');
    repository.offline = true;
    await expectLater(
        service.choose('a', HealthConsentDecision.granted), throwsStateError);
    expect(service.granted, isFalse);
    expect(service.decision, isNull);
    await expectLater(
        service.choose('a', HealthConsentDecision.declined), throwsStateError);
    expect(service.decision, isNull);
  });

  test(
      'offline revocation blocks immediately, survives restart, retries on server',
      () async {
    final repository = _Repository()
      ..decisions['a'] = HealthConsentDecision.granted;
    final service = HealthConsentService(repository);
    await service.load('a');
    final previousRevision = service.revision;
    repository.offline = true;
    final pending = service.choose('a', HealthConsentDecision.revoked);
    expect(service.granted, isFalse);
    expect(service.revision, greaterThan(previousRevision));
    await expectLater(pending, throwsStateError);
    final restored = HealthConsentService(repository);
    await restored.load('a');
    expect(restored.loaded, isTrue);
    expect(restored.revocationPending, isTrue);
    expect(restored.granted, isFalse);
    // Another account is not revoked by a's pending request.
    repository.offline = false;
    repository.decisions['b'] = HealthConsentDecision.granted;
    final other = HealthConsentService(repository);
    await other.load('b');
    expect(other.granted, isTrue);
    await restored.load('a');
    expect(repository.decisions['a'], HealthConsentDecision.revoked);
    expect(restored.revocationPending, isFalse);
    expect(restored.granted, isFalse);
  });

  test('server revocation is silently detected before import', () async {
    final repository = _Repository()
      ..decisions['a'] = HealthConsentDecision.granted;
    final service = HealthConsentService(repository);
    await service.load('a');
    repository.decisions['a'] = HealthConsentDecision.revoked;
    expect(await service.verify('a'), isFalse);
    expect(service.decision, HealthConsentDecision.revoked);
  });

  test('verification failure stops imports but preserves the previous choice',
      () async {
    final repository = _Repository()
      ..decisions['a'] = HealthConsentDecision.granted;
    final service = HealthConsentService(repository);
    await service.load('a');
    repository.offline = true;
    expect(await service.verify('a'), isFalse);
    expect(service.loaded, isTrue);
    expect(service.decision, HealthConsentDecision.granted);
    repository.offline = false;
    await service.load('a');
    expect(service.granted, isTrue);
  });

  test('late server response cannot grant the next signed-in account',
      () async {
    final repository = _Repository();
    final service = HealthConsentService(repository);
    final delayed = Completer<HealthConsentDecision?>();
    repository.delayedRead = delayed;
    final loading = service.load('a');
    await Future<void>.delayed(Duration.zero);
    repository.delayedRead = null;
    await service.load('b');
    delayed.complete(HealthConsentDecision.granted);
    await loading;
    expect(service.belongsTo('b'), isTrue);
    expect(service.granted, isFalse);
    expect(service.decision, isNull);
  });

  test('late grant after sign-out cannot restore local authorization',
      () async {
    final repository = _Repository();
    final service = HealthConsentService(repository);
    await service.load('a');
    repository.delayedWrite = Completer<void>();
    final saving = service.choose('a', HealthConsentDecision.granted);
    service.reset();
    repository.delayedWrite!.complete();
    await expectLater(saving, throwsStateError);
    expect(service.granted, isFalse);
    expect(service.belongsTo('a'), isFalse);
  });
}
