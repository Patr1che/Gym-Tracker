import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/measurement_entry.dart';
import 'package:gym_tracker/core/models/workout_log.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/core/providers/app_providers.dart';
import 'package:gym_tracker/core/theme/app_theme.dart';
import 'package:gym_tracker/core/widgets/gradient_background.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:gym_tracker/features/exercises/presentation/screens/exercise_detail_screen.dart';
import 'package:gym_tracker/features/history/presentation/history_screen.dart';
import 'package:gym_tracker/features/history/presentation/workout_detail_screen.dart';
import 'package:gym_tracker/features/home/presentation/home_screen.dart';
import 'package:gym_tracker/features/measurements/presentation/measurement_providers.dart';
import 'package:gym_tracker/features/measurements/presentation/measurements_screen.dart';
import 'package:gym_tracker/features/profile/presentation/edit_profile_screen.dart';
import 'package:gym_tracker/features/profile/presentation/profile_screen.dart';
import 'package:gym_tracker/features/programs/presentation/program_detail_screen.dart';
import 'package:gym_tracker/features/programs/presentation/programs_screen.dart';
import 'package:gym_tracker/features/progress/presentation/progress_screen.dart';
import 'package:gym_tracker/features/settings/presentation/screens/static_pages.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';
import 'package:gym_tracker/features/settings/presentation/settings_screen.dart';
import 'package:gym_tracker/features/workout_session/presentation/session_controller.dart';
import 'package:gym_tracker/seed/exercise_seed_data.dart';
import 'package:gym_tracker/seed/program_seed_data.dart';
import 'package:gym_tracker/seed/seeder.dart';

import 'helpers/fake_json_box.dart';
import 'helpers/test_harness.dart';

/// Renders every screen at phone width with realistic data. Layout overflows
/// throw in tests, so these catch responsive regressions the feature tests
/// (which run at the default 800x600) would miss.
void main() {
  final today = DateTime(2026, 8, 7, 9);
  late FakeJsonBox exercises;
  late FakeJsonBox programs;
  late FakeJsonBox meta;
  late FakeMeasurementRepository measurementRepo;
  late FakeWorkoutLogRepository logRepo;

  WorkoutLog sampleLog() => WorkoutLog(
        id: 'w1',
        userId: 'u1',
        programId: 'prog_ppl',
        dayName: 'Push',
        startedAt: DateTime(2026, 8, 6, 18),
        endedAt: DateTime(2026, 8, 6, 19, 5),
        durationSec: 3900,
        entries: const [
          ExerciseLog(exerciseId: 'ex_bench_press', sets: [
            SetLog(weightKg: 100, reps: 5, completed: true),
            SetLog(weightKg: 100, reps: 5, completed: true),
            SetLog(weightKg: 95, reps: 8, completed: true, skipped: true),
            SetLog(weightKg: 95, reps: 8),
          ]),
          ExerciseLog(exerciseId: 'ex_shoulder_press', sets: [
            SetLog(weightKg: 55, reps: 10, completed: true),
          ]),
        ],
        totalVolumeKg: 1550,
        totalSets: 3,
        caloriesEst: 433,
      );

  setUp(() async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(430, 932);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    exercises = FakeJsonBox();
    programs = FakeJsonBox();
    meta = FakeJsonBox();
    await runSeeder(exercises: exercises, programs: programs, meta: meta);

    logRepo = FakeWorkoutLogRepository([sampleLog()]);
    measurementRepo = FakeMeasurementRepository();
    for (var i = 0; i < 4; i++) {
      await measurementRepo.save(MeasurementEntry(
        id: 'm$i',
        userId: 'u1',
        date: DateTime(2026, 7, 10 + i * 7),
        weightKg: 84.0 - i * 0.6,
        bodyFatPct: 18.5 - i * 0.3,
        chestCm: 104,
        waistCm: 84.0 - i,
        armsCm: 38.5,
        legsCm: 60,
        shouldersCm: 122,
        neckCm: 39,
        hipsCm: 98,
      ));
    }
  });

  List<Override> overrides() => [
        clockProvider.overrideWithValue(() => today),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(users: [testUser()])),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
        favoritesBoxProvider.overrideWithValue(FakeJsonBox()),
        exerciseVideosBoxProvider.overrideWithValue(FakeJsonBox()),
        activeSessionBoxProvider.overrideWithValue(FakeJsonBox()),
        measurementsBoxProvider.overrideWithValue(FakeJsonBox()),
        exercisesBoxProvider.overrideWithValue(exercises),
        programsBoxProvider.overrideWithValue(programs),
        metaBoxProvider.overrideWithValue(meta),
        measurementRepositoryProvider.overrideWithValue(measurementRepo),
        workoutLogRepositoryProvider.overrideWithValue(logRepo),
      ];

  /// Pumps [screen] at phone width and fails on any layout overflow.
  Future<void> renders(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: GradientBackground(child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('home dashboard', (tester) async {
    await renders(tester, const HomeScreen());
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
  });

  testWidgets('programs list', (tester) async {
    await renders(tester, const ProgramsScreen());
    expect(find.text('Push Pull Legs'), findsOneWidget);
  });

  testWidgets('program detail for every seeded program', (tester) async {
    for (final seed in programSeeds) {
      await renders(
          tester, ProgramDetailScreen(programId: seed['id'] as String));
      expect(find.text(seed['name'] as String), findsWidgets);
    }
  });

  testWidgets('exercise detail for every seeded exercise', (tester) async {
    // The longest names, descriptions, and tip lists are the overflow risk.
    for (final seed in exerciseSeeds) {
      await renders(
          tester, ExerciseDetailScreen(exerciseId: seed['id'] as String));
    }
  });

  testWidgets('history list and workout detail', (tester) async {
    await renders(tester, const HistoryScreen());
    expect(find.text('Push'), findsOneWidget);

    await renders(tester, const WorkoutDetailScreen(logId: 'w1'));
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('progress with charts and personal records', (tester) async {
    await renders(tester, const ProgressScreen());
    expect(find.text('Weight trend'), findsOneWidget);

    // PR cards sit at the bottom of a long scroll.
    await tester.dragUntilVisible(
      find.text('Personal records'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('measurements with chart and log history', (tester) async {
    await renders(tester, const MeasurementsScreen());
    expect(find.text('Weight over time'), findsOneWidget);
  });

  testWidgets('profile, edit profile, and settings', (tester) async {
    await renders(tester, const ProfileScreen());
    expect(find.text('Alex Smith'), findsOneWidget);

    await renders(tester, const EditProfileScreen());
    expect(find.text('Edit Profile'), findsOneWidget);

    await renders(tester, const SettingsScreen());
    expect(find.text('Rest timer sound'), findsOneWidget);
  });

  testWidgets('static settings pages', (tester) async {
    await renders(tester, const PrivacyScreen());
    await renders(tester, const TermsScreen());
    await renders(tester, const AboutScreen());
    await renders(tester, const FeedbackScreen());
  });

  testWidgets('forgot password', (tester) async {
    await renders(tester, const ForgotPasswordScreen());
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('screens render in light mode too', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GradientBackground(child: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
