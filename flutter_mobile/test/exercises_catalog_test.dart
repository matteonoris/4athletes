import 'package:flutter_mobile/data/exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExerciseDef exercise(String id) =>
      exerciseDatabase.firstWhere((item) => item.id == id);

  test('warm-up and cool-down accept exercises from every discipline', () {
    const strengthOnly = {'strength'};

    expect(
      exerciseMatchesTrainingPhase(
        exercise('treadmill_run'),
        phase: 'warmup',
        mainPhaseCategories: strengthOnly,
      ),
      isTrue,
    );
    expect(
      exerciseMatchesTrainingPhase(
        exercise('mob_ankle_drill'),
        phase: 'cooldown',
        mainPhaseCategories: strengthOnly,
      ),
      isTrue,
    );
    expect(
      exerciseMatchesTrainingPhase(
        exercise('box_jump'),
        phase: 'warmup',
        mainPhaseCategories: const {'mobility'},
      ),
      isTrue,
    );
  });

  test('main phase remains specific to the selected discipline', () {
    const strengthOnly = {'strength'};

    expect(
      exerciseMatchesTrainingPhase(
        exercise('power_clean'),
        phase: 'main',
        mainPhaseCategories: strengthOnly,
      ),
      isTrue,
    );
    expect(
      exerciseMatchesTrainingPhase(
        exercise('treadmill_run'),
        phase: 'main',
        mainPhaseCategories: strengthOnly,
      ),
      isFalse,
    );
  });

  test('plyometric catalogue is broad, unique and correctly classified', () {
    final plyometricExercises = exerciseDatabase
        .where((item) => item.resolvedActivityCategory == 'plyometrics')
        .toList();
    final uniqueIds = plyometricExercises.map((item) => item.id).toSet();

    expect(plyometricExercises.length, greaterThanOrEqualTo(65));
    expect(uniqueIds.length, plyometricExercises.length);
    expect(
      plyometricExercises.map((item) => item.id),
      containsAll([
        'plyo_pogo_jump',
        'plyo_countermovement_jump',
        'plyo_repeated_broad_jump',
        'plyo_lateral_bound',
        'plyo_single_leg_hop_stick',
        'plyo_depth_jump',
        'plyo_pushup',
        'plyo_med_ball_rotational_throw',
        'plyo_trap_bar_jump',
      ]),
    );
  });

  test('speed and agility catalogue is broad, unique and distance-aware', () {
    final speedExercises = exerciseDatabase
        .where((item) => item.resolvedActivityCategory == 'speed_agility')
        .toList();
    final uniqueIds = speedExercises.map((item) => item.id).toSet();

    expect(speedExercises.length, greaterThanOrEqualTo(65));
    expect(uniqueIds.length, speedExercises.length);
    expect(
      speedExercises.map((item) => item.id),
      containsAll([
        'speed_wall_march',
        'speed_falling_start',
        'speed_flying_20',
        'speed_sprint_to_stick',
        'speed_5_10_5',
        'speed_mirror_drill',
        'speed_ladder_icky_shuffle',
      ]),
    );
    expect(
        speedExercises.every((item) => item.usesSpeedAgilityTracking), isTrue);
    expect(
      speedExercises.every((item) => (item.defaultTrials ?? 0) > 0),
      isTrue,
    );
    expect(
      speedExercises.every((item) => (item.defaultDistanceMeters ?? 0) > 0),
      isTrue,
    );
  });
}
