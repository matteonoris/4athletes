import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AccountDeletionRepository {
  Future<String> request(String receipt);
  Future<String?> status(String receipt);
}

class SupabaseAccountDeletionRepository implements AccountDeletionRepository {
  SupabaseAccountDeletionRepository(this.client);
  final SupabaseClient client;

  @override
  Future<String> request(String receipt) async {
    final result = await client.rpc('request_account_deletion',
        params: {'confirmation': 'ELIMINA', 'receipt': receipt});
    return result['status'] as String;
  }

  @override
  Future<String?> status(String receipt) async {
    final result = await client
        .rpc('account_deletion_status', params: {'receipt': receipt});
    return result?['status'] as String?;
  }
}

class RecentLoginRequired implements Exception {}

class AccountDeletionService {
  AccountDeletionService(this.repository, this.preferences);
  final AccountDeletionRepository repository;
  final SharedPreferences preferences;
  static const receiptKey = 'pending_account_deletion_receipt';
  static const ownerKey = 'pending_account_deletion_owner';
  static const acceptedKey = 'pending_account_deletion_accepted';
  String? get receipt => preferences.getString(receiptKey);
  String? get owner => preferences.getString(ownerKey);
  bool get accepted => preferences.getBool(acceptedKey) == true;

  static Future<AccountDeletionService> create() async =>
      AccountDeletionService(
          SupabaseAccountDeletionRepository(Supabase.instance.client),
          await SharedPreferences.getInstance());

  Future<String?> status() async {
    final token = receipt;
    return token == null ? null : repository.status(token);
  }

  Future<String> request(String userId) async {
    if (userId.isEmpty) throw RecentLoginRequired();
    var token = receipt;
    if (token == null || owner != userId) {
      final random = Random.secure();
      token = List.generate(
              32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      // Save before submitting, so a lost response/restart can be reconciled.
      if (!await preferences.setString(ownerKey, userId) ||
          !await preferences.setString(receiptKey, token)) {
        throw StateError('Cannot persist deletion receipt');
      }
      await preferences.remove(acceptedKey);
    } else {
      final known = await repository.status(token);
      if (known != null) {
        await preferences.setBool(acceptedKey, true);
        return known;
      }
    }
    try {
      final result = await repository.request(token);
      await preferences.setBool(acceptedKey, true);
      return result;
    } catch (error) {
      // The server may have committed before the connection failed. Do not
      // report failure or issue a different destructive request in that case.
      try {
        final known = await repository.status(token);
        if (known != null) {
          await preferences.setBool(acceptedKey, true);
          return known;
        }
      } catch (_) {/* Keep the receipt for later reconciliation. */}
      if (error is PostgrestException &&
          error.hint == 'recent_login_required') {
        throw RecentLoginRequired();
      }
      rethrow;
    }
  }

  Future<void> forgetReceipt() async {
    await preferences.remove(receiptKey);
    await preferences.remove(ownerKey);
    await preferences.remove(acceptedKey);
  }
}

/// Erases app-owned local records, preserving unrelated accounts' scoped
/// caches and the receipt needed to check an accepted deletion after logout.
Future<void> clearDeletedAccountPreferences(
    SharedPreferences prefs, String owner,
    {bool includeUnscoped = true}) async {
  if (owner.isEmpty) throw ArgumentError.value(owner, 'owner');
  const unscoped = {
    'isLoggedIn',
    'userProfile',
    'workoutTemplates',
    'healthAccessEnabled',
    'notificationsEnabled',
  };
  for (final key in prefs.getKeys().toList()) {
    final scoped = key.contains(owner) &&
        (key.startsWith('health_') ||
            key.startsWith('healthAccessEnabled_') ||
            key.startsWith('workout_draft_'));
    final legacy = RegExp(r'^health_sync_v\d+_.*\d{4}-\d{2}-\d{2}$')
            .hasMatch(key) &&
        !RegExp(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}')
            .hasMatch(key);
    if (scoped || (includeUnscoped && (unscoped.contains(key) || legacy))) {
      if (!await prefs.remove(key)) {
        throw StateError('Cannot clear personal cache');
      }
    }
  }
}
