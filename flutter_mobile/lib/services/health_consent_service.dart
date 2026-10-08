import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const healthConsentNoticeVersion = '2026-10-04';

enum HealthConsentDecision { granted, declined, revoked }

abstract class HealthConsentRepository {
  Future<HealthConsentDecision?> latest(String userId);
  Future<void> record(String userId, HealthConsentDecision decision);
}

class SupabaseHealthConsentRepository implements HealthConsentRepository {
  SupabaseHealthConsentRepository(this.client);
  final SupabaseClient client;

  @override
  Future<HealthConsentDecision?> latest(String userId) async {
    final rows = await client
        .from('health_consent_events')
        .select('decision,notice_version')
        .eq('user_id', userId)
        .order('id', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    // A different disclosure must be presented again before importing.
    if (rows.first['notice_version'] != healthConsentNoticeVersion) return null;
    return HealthConsentDecision.values
        .byName(rows.first['decision'] as String);
  }

  @override
  Future<void> record(String userId, HealthConsentDecision decision) async {
    await client.from('health_consent_events').insert({
      'user_id': userId,
      'decision': decision.name,
      'notice_version': healthConsentNoticeVersion,
    });
  }
}

/// Fails closed on unavailable server state. Local revocation survives a restart
/// and is uploaded on the next successful load; it is never a local grant.
class HealthConsentService extends ChangeNotifier {
  HealthConsentService(this.repository);
  final HealthConsentRepository repository;
  String? _owner;
  HealthConsentDecision? decision;
  bool loaded = false;
  bool loadFailed = false;
  bool revocationPending = false;
  int revision = 0;
  int _operation = 0;

  bool get granted =>
      loaded &&
      !loadFailed &&
      !revocationPending &&
      decision == HealthConsentDecision.granted;
  bool belongsTo(String owner) => owner.isNotEmpty && _owner == owner;
  bool get mayVerify =>
      loaded && !revocationPending && decision == HealthConsentDecision.granted;
  String _stopKey(String owner) => 'health_consent_pending_revocation_$owner';

  void reset() {
    _owner = null;
    decision = null;
    loaded = false;
    loadFailed = false;
    revocationPending = false;
    _operation++;
    revision++;
    notifyListeners();
  }

  Future<void> load(String owner) async {
    if (owner.isEmpty) {
      reset();
      return;
    }
    if (_owner != owner) {
      reset();
      _owner = owner;
    }
    final operation = ++_operation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (operation != _operation) return;
      if (prefs.getBool(_stopKey(owner)) == true) {
        decision = HealthConsentDecision.revoked;
        revocationPending = true;
        revision++;
        notifyListeners();
        await repository.record(owner, HealthConsentDecision.revoked);
        if (operation != _operation) return;
        await prefs.remove(_stopKey(owner));
      }
      final latest = await repository.latest(owner);
      if (operation != _operation) return;
      if (decision != latest || loadFailed || !loaded) revision++;
      decision = latest;
      loaded = true;
      loadFailed = false;
      revocationPending = false;
    } catch (_) {
      if (operation != _operation) return;
      loadFailed = true;
      // Pending revocation is already a choice; allow app use without imports.
      loaded = revocationPending || decision != null || loaded;
      revision++;
    }
    if (operation == _operation) notifyListeners();
  }

  Future<void> choose(String owner, HealthConsentDecision choice) async {
    if (owner.isEmpty || !belongsTo(owner)) {
      throw StateError('Account changed');
    }
    final operation = ++_operation;
    if (choice == HealthConsentDecision.revoked) {
      decision = choice;
      revocationPending = true;
      revision++;
      notifyListeners();
    }
    if (choice == HealthConsentDecision.revoked) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(_stopKey(owner), true)) {
        throw StateError('Cannot preserve revocation');
      }
    }
    await repository.record(owner, choice);
    if (operation != _operation || !belongsTo(owner)) {
      throw StateError('Account changed');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stopKey(owner));
    if (operation != _operation || !belongsTo(owner)) {
      throw StateError('Account changed');
    }
    decision = choice;
    loaded = true;
    loadFailed = false;
    revocationPending = false;
    revision++;
    notifyListeners();
  }

  Future<bool> verify(String owner) async {
    if (!belongsTo(owner) || !mayVerify) return false;
    await load(owner);
    return belongsTo(owner) && granted;
  }
}
