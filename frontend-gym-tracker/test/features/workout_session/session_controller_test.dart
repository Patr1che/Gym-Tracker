import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/core/providers/app_providers.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/exercises/presentation/exercise_providers.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';
import 'package:gym_tracker/features/workout_session/presentation/session_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeAuthRepository authRepo;
  late FakeWorkoutLogRepository logRepo;
  late FakeJsonBox activeSessionBox;
  late DateTime now;
  var idCounter = 0;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        uuidProvider.overrideWithValue(() => 'id_${idCounter++}'),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        workoutLogRepositoryProvider.overrideWithValue(logRepo),
        activeSessionBoxProvider.overrideWithValue(activeSessionBox),
        settingsRepositoryProvider
            .overrideWithValue(FakeSettingsRepository()),
        exerciseRepositoryProvider.overrideWithValue(
          FakeExerciseRepository([
            testExercise(id: 'ex_bench_press', name: 'Bench Press'),
            testExercise(id: 'ex_squat', name: 'Squat'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    now = DateTime(2026, 8, 7, 10);
    idCounter = 0;
    authRepo = FakeAuthRepository(users: [testUser()]);
    logRepo = FakeWorkoutLogRepository();
    activeSessionBox = FakeJsonBox();
  });

  void startWorkout(ProviderContainer container) {
    final program = testProgram();
    container.read(sessionControllerProvider.notifier).start(
          program: program,
          day: program.days.first,
          resolve: container.read(exerciseRepositoryProvider).byId,
        );
  }

  test('start builds a session with one SetLog per programmed set', () {
    final container = makeContainer();
    startWorkout(container);

    final session = container.read(sessionControllerProvider)!;
    expect(session.exercises, hasLength(2));
    expect(session.exercises.first.exerciseName, 'Bench Press');
    expect(session.exercises.first.sets, hasLength(2));
    expect(session.totalSets, 4);
    expect(session.completedSets, 0);
    // Reps prefill from the lower bound of the target range.
    expect(session.exercises.first.sets.first.reps, 8);
    expect(session.exercises[1].sets.first.reps, 6);
  });

  test('start persists a snapshot so a refresh can resume', () {
    final container = makeContainer();
    startWorkout(container);
    expect(activeSessionBox.get('u1'), isNotNull);
  });

  test('completeSet records the set and starts the rest timer', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 100, reps: 5);
    controller.completeSet();

    final session = container.read(sessionControllerProvider)!;
    final firstSet = session.exercises.first.sets.first;
    expect(firstSet.completed, isTrue);
    expect(firstSet.weightKg, 100);
    expect(firstSet.reps, 5);
    expect(session.resting, isTrue);
    // Bench press rest is 60s in the fixture.
    expect(session.restEndsAt, now.add(const Duration(seconds: 60)));
  });

  test('a completed set seeds the sets still to come', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 60, reps: 12);
    controller.completeSet();

    final upcoming =
        container.read(sessionControllerProvider)!.exercises.first.sets[1];
    expect(upcoming.weightKg, 60);
    expect(upcoming.reps, 12);
    expect(upcoming.completed, isFalse, reason: 'seeded, not performed');
  });

  test('the seed follows the latest set, and edits still win', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 60, reps: 12);
    controller.completeSet();
    // Second set: drop the weight, which must not be overwritten.
    controller.updateCurrentSet(weightKg: 50, reps: 10);

    final sets =
        container.read(sessionControllerProvider)!.exercises.first.sets;
    expect(sets[1].weightKg, 50);
    expect(sets[1].reps, 10);
    // The finished set keeps what was actually lifted.
    expect(sets[0].weightKg, 60);
    expect(sets[0].reps, 12);
  });

  test('seeded-but-unperformed sets stay out of the saved log', () async {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 60, reps: 12);
    controller.completeSet();
    final summary = await controller.finish();

    // One completed set only — the seeded second set must not add volume.
    expect(summary!.log.totalSets, 1);
    expect(summary.log.totalVolumeKg, 60 * 12);
  });

  test('restRemainingSeconds derives from the clock, not tick counting', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);
    controller.completeSet();

    expect(controller.restRemainingSeconds, 60);
    now = now.add(const Duration(seconds: 45));
    expect(controller.restRemainingSeconds, 15);
    now = now.add(const Duration(seconds: 30));
    expect(controller.restRemainingSeconds, 0);
  });

  test('skipRest and extendRest adjust the timer', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);
    controller.completeSet();

    controller.extendRest();
    expect(controller.restRemainingSeconds, 90);

    controller.skipRest();
    expect(container.read(sessionControllerProvider)!.resting, isFalse);
    expect(controller.restRemainingSeconds, 0);
  });

  test('finishing an exercise auto-advances to the next one', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    expect(container.read(sessionControllerProvider)!.currentIndex, 0);
    controller.completeSet();
    controller.completeSet();

    final session = container.read(sessionControllerProvider)!;
    expect(session.exercises.first.isDone, isTrue);
    expect(session.currentIndex, 1);
  });

  test('skipSet marks the set skipped without completing it', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.skipSet();
    final set = container.read(sessionControllerProvider)!.exercises.first.sets.first;
    expect(set.skipped, isTrue);
    expect(set.completed, isFalse);
    expect(set.counts, isFalse);
  });

  test('next/previous exercise navigation clamps at the ends', () {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.previousExercise();
    expect(container.read(sessionControllerProvider)!.currentIndex, 0);

    controller.nextExercise();
    expect(container.read(sessionControllerProvider)!.currentIndex, 1);

    controller.nextExercise();
    expect(container.read(sessionControllerProvider)!.currentIndex, 1);
  });

  test('finish computes totals, saves the log, and clears the session',
      () async {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 100, reps: 5);
    controller.completeSet();
    controller.updateCurrentSet(weightKg: 100, reps: 5);
    controller.completeSet();
    // Now on squat: one counted set, one skipped.
    controller.updateCurrentSet(weightKg: 140, reps: 3);
    controller.completeSet();
    controller.skipSet();

    now = now.add(const Duration(minutes: 45));
    final summary = await controller.finish();

    expect(summary, isNotNull);
    final log = summary!.log;
    expect(log.totalVolumeKg, 100 * 5 * 2 + 140 * 3);
    expect(log.totalSets, 3);
    expect(log.durationSec, 45 * 60);
    // MET 5 × 80 kg × 0.75 h = 300 kcal.
    expect(log.caloriesEst, 300);
    expect(log.entries, hasLength(2));

    expect(logRepo.saved.values.single.id, log.id);
    expect(container.read(sessionControllerProvider), isNull);
    expect(activeSessionBox.get('u1'), isNull);
  });

  test('finish reports new personal records for key lifts', () async {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    controller.updateCurrentSet(weightKg: 100, reps: 5);
    controller.completeSet();
    now = now.add(const Duration(minutes: 30));
    final summary = await controller.finish();

    expect(summary!.newPrs, isNotEmpty);
    expect(summary.newPrs.every((pr) => pr.exerciseId == 'ex_bench_press'),
        isTrue);
  });

  test('abandon discards the session and its snapshot', () async {
    final container = makeContainer();
    startWorkout(container);
    final controller = container.read(sessionControllerProvider.notifier);

    await controller.abandon();

    expect(container.read(sessionControllerProvider), isNull);
    expect(activeSessionBox.get('u1'), isNull);
    expect(logRepo.saved, isEmpty);
  });

  test('a persisted snapshot is restored on rebuild', () {
    final first = makeContainer();
    startWorkout(first);
    first.read(sessionControllerProvider.notifier).completeSet();
    final before = first.read(sessionControllerProvider)!;

    // A fresh container reads the same box — as after a browser refresh.
    final second = makeContainer();
    final restored = second.read(sessionControllerProvider);

    expect(restored, isNotNull);
    expect(restored!.dayName, before.dayName);
    expect(restored.completedSets, 1);
    expect(restored.restEndsAt, before.restEndsAt);
  });
}
