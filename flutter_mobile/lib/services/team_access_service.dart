import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'private_avatar_service.dart';

typedef TeamRpc = Future<dynamic> Function(
    String name, Map<String, dynamic> params);

class TeamAccessService {
  final SupabaseClient? client;
  final TeamRpc? rpcOverride;
  TeamAccessService(this.client, {this.rpcOverride});

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      rpcOverride != null
          ? rpcOverride!(name, params)
          : client!.rpc(name, params: params);

  Future<Map<String, dynamic>> operation(
    String action, {
    String? teamId,
    String? subjectId,
    Map<String, dynamic> payload = const {},
  }) async {
    final result = Map<String, dynamic>.from(await _rpc('team_operation', {
      'operation': action,
      't': teamId,
      'subject': subjectId,
      'payload': payload,
    }));
    if (result['error'] != null) throw StateError(result['error'].toString());
    return result;
  }

  Future<List<Team>> teams() async {
    final rows = await _rpc('get_my_teams', {});
    return (rows as List)
        .map((row) => Team.fromServer(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> directory(String teamId,
      {bool includePending = false}) async {
    final rows = await _rpc(
        'team_directory', {'t': teamId, 'include_pending': includePending});
    final result =
        (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
    if (client != null) {
      for (final row in result) {
        row['avatar_url'] = await PrivateAvatarService(client!)
            .resolve(row['avatar_url']?.toString() ?? '');
      }
    }
    return result;
  }
}
