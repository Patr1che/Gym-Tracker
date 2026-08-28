import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/core/providers/app_providers.dart';
import 'package:gym_tracker/core/router/app_router.dart';
import 'package:gym_tracker/core/router/routes.dart';
import 'package:gym_tracker/core/theme/app_theme.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/exercises/presentation/exercise_providers.dart';
import 'package:gym_tracker/features/exercises/presentation/screens/exercise_detail_screen.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';
import 'package:gym_tracker/features/workout_session/presentation/active_session_screen.dart';
import 'package:gym_tracker/features/workout_session/presentation/session_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeWorkoutLogRepository logRepo;
  late FakeJsonBox activeSessionBox;
  late DateTime now;

  List<Override> overrides() => [
        localOnly,
        clockProvider.overrideWithValue(() => now),
        uuidProvider.overrideWithValue(() => 'log_1'),
        favoritesBoxProvider.overrideWithValue(FakeJsonBox()),
        exerciseVideosBoxProvider.overrideWithValue(FakeJsonBox()),
        // The inline player is a WebView with no implementation under
        // `flutter test` — render the no-video panel instead.
        effectiveVideoIdProvider.overrideWith((ref, id) => null),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(users: [testUser()])),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
        activeSessionBoxProvider.overrideWithValue(activeSessionBox),
        workoutLogRepositoryProvider.overrideWithValue(logRepo),
        exerciseRepositoryProvider.overrideWithValue(
          FakeExerciseRepository([
            testExercise(id: 'ex_bench_press', name: 'Bench Press'),
            testExercise(id: 'ex_squat', name: 'Squat'),
          ]),
        ),
      ];

  setUp(() {
    now = DateTime(2026, 8, 7, 10);
    logRepo = FakeWorkoutLogRepository();
    activeSessionBox = FakeJsonBox();
  });

  /// Pumps the screen with a session already started, and returns the
  /// container so tests can inspect controller state.
  Future<ProviderContainer> pumpSession(WidgetTester tester) async {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);

    final program = testProgram();
    container.read(sessionControllerProvider.notifier).start(
          program: program,
          day: program.days.first,
          resolve: container.read(exerciseRepositoryProvider).byId,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ActiveSessionScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  /// The rest ticker is a real periodic Timer; the test framework fails on
  /// pending timers, so tests that end mid-rest must stop it first.
  Future<void> stopRest(WidgetTester tester, ProviderContainer container) async {
    if (container.read(sessionControllerProvider)?.resting ?? false) {
      container.read(sessionControllerProvider.notifier).skipRest();
      await tester.pump();
    }
  }

  testWidgets('shows the current exercise, set position, and progress',
      (tester) async {
    await pumpSession(tester);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Exercise 1 of 2'), findsOneWidget);
    expect(find.text('Current set'), findsOneWidget);
    expect(find.text('0/4 sets'), findsOneWidget);
    expect(find.text('Complete Set'), findsOneWidget);
  });

  testWidgets('completing a set advances progress and opens the rest timer',
      (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Complete Set'));
    await tester.pump();

    expect(find.text('1/4 sets'), findsOneWidget);
    expect(find.text('Rest up 💨'), findsOneWidget);
    // Bench press rest is 60s in the fixture.
    expect(find.text('1:00'), findsWidgets);
    expect(container.read(sessionControllerProvider)!.resting, isTrue);

    await stopRest(tester, container);
  });

  testWidgets('the rest countdown follows the clock', (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Complete Set'));
    await tester.pump();

    now = now.add(const Duration(seconds: 45));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('0:15'), findsWidgets);

    // Past the end, the ticker cancels itself and rest clears.
    now = now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(sessionControllerProvider)!.resting, isFalse);
    expect(find.text('Complete Set'), findsOneWidget);
  });

  testWidgets('skipping rest returns to the set controls', (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Complete Set'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(container.read(sessionControllerProvider)!.resting, isFalse);
    expect(find.text('Complete Set'), findsOneWidget);
    expect(find.text('Rest up 💨'), findsNothing);
  });

  testWidgets('entering weight and reps records them on the set',
      (tester) async {
    final container = await pumpSession(tester);

    final numberFields = find.byType(TextField);
    await tester.enterText(numberFields.at(0), '100');
    await tester.enterText(numberFields.at(1), '5');
    await tester.pump();

    await tester.tap(find.text('Complete Set'));
    await tester.pump();

    final set =
        container.read(sessionControllerProvider)!.exercises.first.sets.first;
    expect(set.weightKg, 100);
    expect(set.reps, 5);
    expect(set.completed, isTrue);

    await stopRest(tester, container);
  });

  testWidgets('the next set opens pre-filled with what was just lifted',
      (tester) async {
    final container = await pumpSession(tester);

    await tester.enterText(find.byType(TextField).at(0), '60');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.pump();
    await tester.tap(find.text('Complete Set'));
    await tester.pump();

    // Set 2 is now the editable one; only the current set renders inputs.
    expect(find.byType(TextField), findsNWidgets(2));
    final weight = tester.widget<TextField>(find.byType(TextField).at(0));
    final reps = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(weight.controller!.text, contains('60'));
    expect(reps.controller!.text, '12');

    await stopRest(tester, container);
  });

  testWidgets('finishing the last set of an exercise moves to the next',
      (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Complete Set'));
    await tester.pump();
    await tester.tap(find.text('Skip')); // skip rest
    await tester.pump();
    await tester.tap(find.text('Complete Set'));
    await tester.pump();

    expect(container.read(sessionControllerProvider)!.currentIndex, 1);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Exercise 2 of 2'), findsOneWidget);

    await stopRest(tester, container);
  });

  testWidgets('finishing early asks for confirmation and saves on confirm',
      (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Complete Set'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    now = now.add(const Duration(minutes: 30));
    await tester.tap(find.text('Finish Workout'));
    await tester.pumpAndSettle();

    expect(find.text('Finish workout?'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Finish').last);
    await tester.pumpAndSettle();

    expect(find.text('Workout complete! 🎉'), findsOneWidget);
    expect(logRepo.saved, hasLength(1));
    expect(container.read(sessionControllerProvider), isNull);
  });

  testWidgets('cancelling the finish dialog keeps the workout running',
      (tester) async {
    final container = await pumpSession(tester);

    await tester.tap(find.text('Finish Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(container.read(sessionControllerProvider), isNotNull);
    expect(logRepo.saved, isEmpty);
  });

  // A clipped number input throws no overflow error — it just silently hides
  // digits — so this asserts the width across the phone range instead.
  for (final size in const [Size(320, 640), Size(360, 800), Size(430, 932)]) {
    testWidgets('weight and reps stay typeable at ${size.width.toInt()}dp',
        (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = size;
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      await pumpSession(tester);
      await tester.pumpAndSettle();

      for (final field in [0, 1]) {
        expect(
          tester.getSize(find.byType(TextField).at(field)).width,
          greaterThan(44),
          reason: 'three digits at stat-20 need ~36px of glyphs plus a caret',
        );
      }
      // Same silent failure for the primary action: an ellipsised label
      // throws nothing, so check it has room. "Complete Set" is ~105px in
      // labelLarge; the test font is wider, so measure space, not fit.
      expect(
        tester.getSize(find.text('Complete Set')).width,
        greaterThan(120),
        reason: 'Complete Set label is being squeezed into an ellipsis',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the whole session screen fits a small phone', (tester) async {
    // Matches the 320x640 floor swept in test/screen_render_test.dart.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(320, 640);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final container = await pumpSession(tester);
    await tester.pumpAndSettle();
    expect(find.text('How to'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The rest panel and the summary sheet are the densest layouts here, and
    // neither is reachable from the screen-render sweep.
    await tester.tap(find.text('Complete Set'));
    await tester.pump();
    expect(find.text('Rest up 💨'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await stopRest(tester, container);

    now = now.add(const Duration(minutes: 20));
    await tester.tap(find.text('Finish Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Finish').last);
    await tester.pumpAndSettle();

    expect(find.text('Workout complete! 🎉'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exercise guide opens over the session and pops back to it',
      (tester) async {
    // Uses the real router: the guide must land on /session/exercise/:id so
    // back returns to the workout rather than the exercise library.
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);

    final program = testProgram();
    container.read(sessionControllerProvider.notifier).start(
          program: program,
          day: program.days.first,
          resolve: container.read(exerciseRepositoryProvider).byId,
        );

    final router = container.read(routerProvider);
    router.go(Routes.session);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('How to'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    expect(find.text('How to perform'), findsOneWidget);
    expect(router.state.uri.path, '/session/exercise/ex_bench_press');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.session);
    expect(find.byType(ExerciseDetailScreen), findsNothing);
    expect(find.text('Complete Set'), findsOneWidget);
  });
}
