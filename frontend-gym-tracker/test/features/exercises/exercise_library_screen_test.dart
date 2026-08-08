import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/exercises/presentation/exercise_providers.dart';
import 'package:gym_tracker/features/exercises/presentation/screens/exercise_library_screen.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeJsonBox favoritesBox;

  List<Override> overrides() => [
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(users: [testUser()])),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
        exerciseVideosBoxProvider.overrideWithValue(FakeJsonBox()),
        favoritesBoxProvider.overrideWithValue(favoritesBox),
        exerciseRepositoryProvider.overrideWithValue(
          FakeExerciseRepository([
            testExercise(id: 'ex_bench_press', name: 'Bench Press'),
            testExercise(
                id: 'ex_squat',
                name: 'Barbell Squat',
                group: MuscleGroup.legs),
            testExercise(
                id: 'ex_plank',
                name: 'Plank',
                group: MuscleGroup.core,
                equipment: 'Bodyweight'),
          ]),
        ),
      ];

  setUp(() => favoritesBox = FakeJsonBox());

  testWidgets('lists every exercise by default', (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
  });

  testWidgets('search narrows results by name', (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    await tester.enterText(find.byType(TextField).first, 'squat');
    await tester.pumpAndSettle();

    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
  });

  testWidgets('search also matches equipment', (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    await tester.enterText(find.byType(TextField).first, 'bodyweight');
    await tester.pumpAndSettle();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
  });

  testWidgets('muscle group chip filters the list', (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    // The chip row scrolls horizontally; 'Legs' starts off-screen.
    await tester.dragUntilVisible(
      find.text('Legs'),
      find.byType(ListView).first,
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Plank'), findsNothing);
  });

  testWidgets('an unmatched search shows the empty state with a reset',
      (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    await tester.enterText(find.byType(TextField).first, 'zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No exercises found'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('favoriting persists and the favorites filter applies',
      (tester) async {
    await pumpApp(tester, const ExerciseLibraryScreen(),
        overrides: overrides());

    await tester.tap(find.byTooltip('Add favorite').first);
    await tester.pumpAndSettle();

    expect((favoritesBox.get('u1')!['ids'] as List), contains('ex_bench_press'));

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Barbell Squat'), findsNothing);
  });
}
