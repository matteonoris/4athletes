import 'dart:convert';

import 'package:flutter_mobile/data/workout_catalog.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/models/training_activity_models.dart';
import 'package:flutter_mobile/models/workout_creation_models.dart';
import 'package:flutter_mobile/models/workout_place.dart';
import 'package:flutter_mobile/services/workout_draft_service.dart';
import 'package:flutter_mobile/services/training_activity_service.dart';
import 'package:flutter_mobile/utils/coach_training_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const place = WorkoutPlace(
    name: 'Bormio',
    address: 'Lombardia, Italia',
    latitude: 46.46,
    longitude: 10.37);

void main() {
  WorkoutDraft draft() => WorkoutDraftFactory.create(
        activity: WorkoutCatalog.byId('running'),
        userId: 'athlete',
        creatorRole: 'athlete',
      ).copyWith(location: place.label, locationPlace: place);

  test('preserves selection through draft, session, activity and local restore',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkoutDraftStore(await SharedPreferences.getInstance());
    await store.save('athlete', draft());
    final restored = store.load('athlete')!;
    expect(restored.locationPlace!.toJson(), place.toJson());
    final session = restored.toTrainingSession();
    expect(session.details!['locationPlace'], place.toJson());
    final json = jsonDecode(jsonEncode(session.details!['workoutDraft']))
        as Map<String, dynamic>;
    expect(WorkoutDraft.fromJson(json).locationPlace!.toJson(), place.toJson());
    final activity = TrainingActivity.fromTrainingSession(session);
    expect(activity.locationPlace!.toJson(), place.toJson());
    expect(TrainingActivity.fromJson(activity.toJson()).locationPlace!.toJson(),
        place.toJson());
    expect(
        activity.copyWith(notes: 'Updated').toSessionDetails()['locationPlace'],
        place.toJson());
    final converted = WorkoutDraftFactory.fromTrainingSession(
        session: session,
        activity: WorkoutCatalog.byId('running'),
        userId: 'athlete');
    expect(converted.locationPlace!.toJson(), place.toJson());
  });

  test(
      'editing or clearing location removes stale coordinates from all payloads',
      () {
    expect(draft().copyWith(location: 'Livigno').locationPlace, isNull);
    expect(draft().copyWith(clearLocation: true).locationPlace, isNull);
    final activity =
        TrainingActivity.fromTrainingSession(draft().toTrainingSession());
    expect(activity.copyWith(location: 'Livigno').locationPlace, isNull);
    expect(
        activity.copyWith(clearLocationPlace: true).toSessionDetails(existing: {
          'locationPlace': place.toJson()
        }).containsKey('locationPlace'),
        isFalse);
    final oldDraft = draft().toJson()..remove('locationPlace');
    expect(WorkoutDraft.fromJson(oldDraft).location, place.label);
    expect(WorkoutDraft.fromJson(oldDraft).locationPlace, isNull);
  });

  test('passes coach ski location to athlete alongside specialty data', () {
    final event = CalendarEvent(
        id: 'ski',
        teamId: 'team',
        type: 'training',
        title: 'GS',
        date: '2026-09-23',
        startTime: '09:00',
        endTime: '11:00',
        location: place.label,
        sportCategory: 'ski',
        technicalDetails: {
          'locationPlace': place.toJson(),
          'specialties': ['GS', 'SL'],
          'freeSkiingBySpecialty': {
            'GS': {'specialty': 'GS', 'laps': 3, 'changes': 5},
            'SL': {'specialty': 'SL', 'laps': 2, 'changes': 8},
          },
        });
    final details =
        CoachTrainingUtils.buildSessionDetailsForAttendee(event, {});
    expect(details['location'], place.label);
    expect(details['locationPlace'], place.toJson());
    expect(details['specialties'], ['GS', 'SL']);
    expect((details['freeSkiingBySpecialty'] as Map).keys,
        containsAll(['GS', 'SL']));
  });

  test('rejects corrupt coordinates and accepts legacy text-only locations',
      () {
    for (final invalid in [
      null,
      'Bormio',
      {},
      {...place.toJson(), 'latitude': 91},
      {...place.toJson(), 'longitude': 'NaN'},
      {...place.toJson(), 'name': ''}
    ]) {
      expect(WorkoutPlace.tryParse(invalid), isNull);
    }
    expect(WorkoutPlace.tryParse(place.toJson())!.label, place.label);
  });

  test('coach workout preserves location and respects athlete manual override',
      () {
    final event = CoachWorkoutEventFactory.create(
        draft: draft(),
        team: Team(
            id: 'team',
            name: 'Team',
            members: 1,
            category: 'ski',
            image: '',
            inviteCode: ''),
        coachId: 'coach');
    const service = TrainingActivityService();
    final details = service.buildCoachDrylandSessionDetails(event, {});
    expect(details['location'], place.label);
    expect(details['locationPlace'], place.toJson());
    final overridden = service.buildCoachDrylandSessionDetails(event, {
      'actualDrylandDetails': {'location': 'Palestra', 'locationPlace': null},
    });
    expect(overridden['location'], 'Palestra');
    expect(overridden.containsKey('locationPlace'), isFalse);
  });
}
