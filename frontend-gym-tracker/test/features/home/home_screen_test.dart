import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/program.dart';
import 'package:gym_tracker/core/models/workout_log.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/core/providers/app_providers.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/exercises/presentation/exercise_providers.dart';
import 'package:gym_tracker/features/home/presentation/home_screen.dart';
import 'package:gym_tracker/features/measurements/presentation/measurement_providers.dart';
import 'package:gym_tracker/features/programs/presentation/program_providers.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';
import 'package:gym_tracker/features/workout_session/presentation/session_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  final today = DateTime(2026, 8, 7, 9);

  WorkoutLog log({
    required String id,
    required DateTime date,
    double volume = 5000,
    int calories = 300,
    String dayName = 'Day 1',
  }) =>
      WorkoutLog(
        id: id,
        userId: 'u1',
        programId: 'prog_test',
        dayName: dayName,
        startedAt: date,
        endedAt: date.add(const Duration(minutes: 45)),
        durationSec: 2700,
        entries: const [],
        totalVolumeKg: volume,
        totalSets: 12,
        caloriesEst: calories,
      );

  List<Override> overrides({
    List<WorkoutLog> logs = const [],
    List<Program>? programs,
  }) =>
      [
        clockProvider.overrideWithValue(() => today),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(users: [testUser()])),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
        activeSessionBoxProvider.overrideWithValue(FakeJsonBox()),
        measurementsBoxProvider.overrideWithValue(FakeJsonBox()),
        measurementRepositoryProvider
            .overrideWithValue(FakeMeasurementRepository()),
        workoutLogRepositoryProvider
            .overrideWithValue(FakeWorkoutLogRepository(logs)),
        programRepositoryProvider.overrideWithValue(
            FakeProgramRepository(programs ?? [testProgram()])),
        exerciseRepositoryProvider.overrideWithValue(
          FakeExerciseRepository([
            testExercise(id: 'ex_bench_press', name: 'Bench Press'),
            testExercise(id: 'ex_squat', name: 'Squat'),
          ]),
        ),
      ];

  testWidgets('greets the user and offers a first workout', (tester) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Start Workout'), findsWidgets);
  });

  testWidgets('a new user sees a zero streak and an empty weekly goal',
      (tester) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());

    expect(find.text('Day streak'), findsOneWidget);
    expect(find.text('Start today'), findsOneWidget);
    // The profile fixture targets 4 workouts a week.
    expect(find.text('0 of 4 workouts'), findsOneWidget);
  });

  testWidgets('computes streak and weekly totals from logs', (tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(logs: [
        log(id: 'w1', date: DateTime(2026, 8, 7, 7)), // today (Friday)
        log(id: 'w2', date: DateTime(2026, 8, 6, 7)), // yesterday
        log(id: 'w3', date: DateTime(2026, 8, 5, 7)),
      ]),
    );

    expect(find.text('3'), findsWidgets); // 3-day streak
    expect(find.text('3 of 4 workouts'), findsOneWidget);
    expect(find.text('900'), findsOneWidget); // 3 × 300 kcal this week
    expect(find.text('15.0k kg'), findsOneWidget); // 3 × 5000 kg volume
  });

  testWidgets('suggests the day after the last completed one', (tester) async {
    final program = testProgram(days: [
      ...testProgram().days,
      const ProgramDay(
        id: 'day2',
        name: 'Day 2',
        exercises: [
          ProgramExercise(
              exerciseId: 'ex_squat',
              sets: 3,
              repsText: '8-12',
              restSeconds: 90),
        ],
      ),
    ]);
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(
        logs: [log(id: 'w1', date: DateTime(2026, 8, 6), dayName: 'Day 1')],
        programs: [program],
      ),
    );

    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('quick actions are all present', (tester) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());

    // Quick actions sit below the fold in the test viewport.
    await tester.dragUntilVisible(
      find.text('Quick actions'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('View Progress'), findsOneWidget);
    expect(find.text('Log Weight'), findsOneWidget);
    expect(find.text('View Programs'), findsOneWidget);
  });
}
