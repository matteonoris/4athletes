import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/services/team_access_service.dart';
import 'package:flutter_mobile/services/private_avatar_service.dart';

void main() {
  test('coach join sends only invitation to validated server operation',
      () async {
    final service = TeamAccessService(null, rpcOverride: (name, params) async {
      expect(name, 'team_operation');
      expect(params, {
        'operation': 'join',
        't': null,
        'subject': null,
        'payload': {'code': 'ABC'}
      });
      return {'team_id': 'team', 'status': 'pending'};
    });
    expect(
        (await service.operation('join', payload: {'code': 'ABC'}))['status'],
        'pending');
  });
  test('server invite failure is surfaced instead of treating it as a join',
      () async {
    final service = TeamAccessService(null,
        rpcOverride: (_, __) async => {'error': 'Attendi un minuto'});
    await expectLater(service.operation('join'), throwsStateError);
  });
  test('team permissions come from server membership state', () async {
    final service = TeamAccessService(null,
        rpcOverride: (_, __) async => [
              {
                'id': 'a',
                'name': 'A',
                'members': 3,
                'category': 'Skiing',
                'is_manager': true,
                'membership_status': 'active',
                'invite_code': 'secure'
              },
              {
                'id': 'b',
                'name': 'B',
                'members': 2,
                'category': 'Skiing',
                'is_manager': false,
                'membership_status': 'pending'
              },
            ]);
    final teams = await service.teams();
    expect(teams[0].isManager, true);
    expect(teams[1].isPending, true);
    expect(teams[1].inviteCode, isEmpty);
  });
  test('private avatar stores path and discards expiring token', () {
    expect(
        PrivateAvatarService.reference(
            'https://example.supabase.co/storage/v1/object/sign/avatars/owner/photo.png?token=temporary'),
        'storage:avatars/owner/photo.png');
    expect(PrivateAvatarService.reference('https://example.com/photo.png'),
        'https://example.com/photo.png');
  });
}
