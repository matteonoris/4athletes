import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/utils/coach_training_utils.dart';

void main() {
  test('calculates modular ski volumes with athlete overrides', () {
    final event = CalendarEvent(
      id: 'event_1',
      teamId: 'team_a',
      type: 'training',
      title: 'SL training',
      date: '2026-06-01',
      startTime: '09:00',
      endTime: '12:00',
      sportCategory: 'ski',
      status: CoachTrainingUtils.statusCompleted,
      technicalDetails: {
        'specialties': ['SL'],
        'freeSkiing': {'laps': 3, 'changes': 10},
        'tracks': [
          {'id': 'track_1', 'name': 'Tracciato 1', 'laps': 4, 'gates': 45},
          {'id': 'track_2', 'name': 'Tracciato 2', 'laps': 2, 'gates': 40},
        ],
        'trainingBlocks': [
          {'id': 'training_1', 'laps': 5, 'references': 8},
        ],
      },
      attendees: const [],
    );

    final details = CoachTrainingUtils.buildSessionDetailsForAttendee(event, {
      'id': 'athlete_1',
      'attendanceStatus': CoachTrainingUtils.attendancePresent,
      'freeLaps': 4,
      'trackLaps': {'track_1': 5, 'track_2': 1},
      'trainingBlockLaps': {'training_1': 6},
      'modifiedByAthlete': true,
    });

    final summary = CoachTrainingUtils.volumeFromDetails(details);

    expect(summary.freeLaps, 4);
    expect(summary.freeDirectionChanges, 40);
    expect(summary.poleLaps, 6);
    expect(summary.polePasses, 265);
    expect(summary.polePassesBySpecialty['SL'], 265);
    expect(summary.trainingLaps, 6);
    expect(summary.trainingDirectionChanges, 48);
    expect(summary.totalDirectionChanges, 88);
    expect(summary.totalSkiDirectionChanges, 353);
  });

  test('normalizes legacy attendance state', () {
    expect(
      CoachTrainingUtils.attendeeStatus({'isPresent': true}),
      CoachTrainingUtils.attendancePresent,
    );
    expect(
      CoachTrainingUtils.attendeeStatus({'isPresent': false}),
      CoachTrainingUtils.attendanceAbsent,
    );
    expect(
      CoachTrainingUtils.attendeeStatus({'isPresent': null}),
      CoachTrainingUtils.attendancePending,
    );
  });

  test('calculates pole passes per track without summing gates per lap', () {
    final details = {
      'specialty': 'SL',
      'freeSkiing': {'laps': 5, 'changes': 15},
      'tracks': [
        {'id': 'track_1', 'laps': 10, 'gates': 25},
        {'id': 'track_2', 'laps': 7, 'gates': 28},
      ],
      'trainingBlocks': [
        {'id': 'training_1', 'laps': 4, 'references': 18},
      ],
    };

    final summary = CoachTrainingUtils.volumeFromDetails(details);

    expect(summary.freeLaps, 5);
    expect(summary.freeDirectionChanges, 75);
    expect(summary.poleLaps, 17);
    expect(summary.polePasses, 446);
    expect(summary.trainingLaps, 4);
    expect(summary.trainingDirectionChanges, 72);
    expect(summary.totalDirectionChanges, 147);
    expect(summary.totalSkiDirectionChanges, 593);
    expect(summary.polePassesBySpecialty['SL'], 446);
  });

  test('clamps negative athlete volume values to zero', () {
    final details = {
      'specialty': 'SX',
      'freeSkiing': {'laps': -2, 'changes': 12},
      'tracks': [
        {'id': 'track_1', 'laps': -3, 'gates': 20},
      ],
      'trainingBlocks': [
        {'id': 'training_1', 'laps': 2, 'references': -8},
      ],
    };

    final summary = CoachTrainingUtils.volumeFromDetails(details);

    expect(summary.freeLaps, 0);
    expect(summary.freeDirectionChanges, 0);
    expect(summary.poleLaps, 0);
    expect(summary.polePasses, 0);
    expect(summary.trainingLaps, 2);
    expect(summary.trainingDirectionChanges, 0);
    expect(summary.polePassesBySpecialty, isEmpty);
  });
}
