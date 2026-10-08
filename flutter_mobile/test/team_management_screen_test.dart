import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/screens/team_management_screen.dart';
import 'package:flutter_mobile/services/team_access_service.dart';

void main() {
  final team = Team(
      id: 'team',
      name: 'Team di prova',
      members: 2,
      category: 'Skiing',
      image: '',
      inviteCode: '',
      isManager: true);
  for (final brightness in Brightness.values) {
    testWidgets('approves and promotes coach in ${brightness.name} theme',
        (tester) async {
      String status = 'pending';
      bool manager = false;
      final service =
          TeamAccessService(null, rpcOverride: (name, params) async {
        if (name == 'get_my_teams')
          return [
            {
              'id': 'team',
              'name': 'Team di prova',
              'members': 2,
              'category': 'Skiing',
              'is_manager': true
            }
          ];
        if (name == 'team_directory')
          return [
            {
              'id': 'coach',
              'first_name': 'Luca',
              'last_name': 'Esempio',
              'role': 'coach',
              'status': status,
              'is_manager': manager
            }
          ];
        if (params['operation'] == 'approve') status = 'active';
        if (params['operation'] == 'promote') manager = true;
        return {'team_id': 'team', 'status': status};
      });
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: TeamManagementScreen(team: team, service: service)));
      await tester.pumpAndSettle();
      expect(find.text('In attesa di approvazione'), findsOneWidget);
      await tester.tap(find.text('Approva'));
      await tester.pumpAndSettle();
      expect(find.text('In attesa di approvazione'), findsNothing);
      await tester.tap(find.text('Nomina responsabile'));
      await tester.pumpAndSettle();
      expect(find.text('Responsabile'), findsOneWidget);
      expect(find.text('Rimuovi ruolo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('stale client manager flag cannot display manager operations',
      (tester) async {
    final service = TeamAccessService(null, rpcOverride: (name, params) async {
      expect(name, 'get_my_teams');
      return [
        {
          'id': 'team',
          'name': 'Team di prova',
          'members': 2,
          'category': 'Skiing',
          'is_manager': false
        }
      ];
    });
    await tester.pumpWidget(
        MaterialApp(home: TeamManagementScreen(team: team, service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Gestione riservata ai responsabili.'), findsOneWidget);
    expect(find.text('Approva'), findsNothing);
  });
}
