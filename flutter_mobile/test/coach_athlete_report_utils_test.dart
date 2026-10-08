import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/coach_athlete_report_utils.dart';

void main() {
  test('preparation hours exclude ski variants and cancelled sessions', () {
    final minutes = [
      ('running', '1h 30m', null),
      ('strength', '45m', null),
      ('alpine_skiing', '2h', null),
      ('ski', '1h', null),
      ('skiing', '1h', null),
      ('snowboarding', '1h', null),
      ('cycling', '3h', <String, dynamic>{'status': 'cancelled'}),
    ].fold<int>(0, (total, session) {
      return total +
          CoachAthleteReportUtils.preparationMinutes(
            sportId: session.$1,
            duration: session.$2,
            details: session.$3,
          );
    });

    expect(minutes, 135);
    expect(CoachAthleteReportUtils.preparationHoursLabel(minutes), '2.3h');
  });

  test('presence uses the athlete team and excludes cancelled events', () {
    CalendarEvent event({
      required String id,
      required String teamId,
      required String category,
      required bool present,
      String status = 'completed',
    }) =>
        CalendarEvent(
          id: id,
          teamId: teamId,
          type: 'training',
          title: id,
          date: '2026-09-01',
          startTime: '09:00',
          endTime: '10:00',
          sportCategory: category,
          status: status,
          attendees: [
            {
              'id': 'athlete-1',
              'name': 'Ada Rossi',
              'attendanceStatus': present ? 'present' : 'absent'
            }
          ],
        );

    final presence = CoachAthleteReportUtils.presence(
      events: [
        event(
            id: 'ski-present',
            teamId: 'team-1',
            category: 'ski',
            present: true),
        event(
            id: 'ski-absent',
            teamId: 'team-1',
            category: 'ski',
            present: false),
        event(
            id: 'dryland',
            teamId: 'team-1',
            category: 'dryland',
            present: true),
        event(
            id: 'other-team',
            teamId: 'team-2',
            category: 'ski',
            present: false),
        event(
            id: 'cancelled',
            teamId: 'team-1',
            category: 'ski',
            present: false,
            status: 'cancelled'),
      ],
      athleteId: 'athlete-1',
      athleteName: 'Ada Rossi',
      teamId: 'team-1',
    );

    expect(presence.skiPercent, 50);
    expect(presence.athleticPercent, 100);
  });
}
