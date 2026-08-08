import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/models/program.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/core/providers/app_providers.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/programs/data/hive_custom_program_repository.dart';
import 'package:gym_tracker/features/programs/presentation/custom_program_controller.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeJsonBox box;
  var counter = 0;

  ProviderContainer makeContainer({String userId = 'u1'}) {
    final container = ProviderContainer(overrides: [
      uuidProvider.overrideWithValue(() => 'id${counter++}'),
      customProgramsBoxProvider.overrideWithValue(box),
      settingsBoxProvider.overrideWithValue(FakeJsonBox()),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      authRepositoryProvider
          .overrideWithValue(FakeAuthRepository(users: [testUser(id: userId)])),
      sessionStoreProvider
          .overrideWithValue(FakeSessionStore(userId: userId, rememberMe: true)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    box = FakeJsonBox();
    counter = 0;
  });

  test('a blank program starts with one empty day', () {
    final c = makeContainer();
    final program = c.read(customProgramsProvider.notifier).blank();
    expect(program.days, hasLength(1));
    expect(program.days.single.exercises, isEmpty);
    expect(isCustomProgramId(program.id), isTrue);
  });

  test('saving persists and appears in the list', () async {
    final c = makeContainer();
    final notifier = c.read(customProgramsProvider.notifier);
    final program = notifier.blank();

    await notifier.save(Program(
      id: program.id,
      name: 'My Split',
      description: 'test',
      difficulty: Difficulty.intermediate,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: [
        ProgramDay(id: 'd1', name: 'Day 1', exercises: const [
          ProgramExercise(
              exerciseId: 'ex_bench_press',
              sets: 4,
              repsText: '6-8',
              restSeconds: 120),
        ]),
      ],
    ));

    final saved = c.read(customProgramsProvider);
    expect(saved, hasLength(1));
    expect(saved.single.name, 'My Split');
    expect(saved.single.days.single.exercises.single.sets, 4);
  });

  test('daysPerWeek is derived from the actual days, never trusted', () async {
    final c = makeContainer();
    final notifier = c.read(customProgramsProvider.notifier);
    final base = notifier.blank();

    await notifier.save(Program(
      id: base.id,
      name: 'Three Day',
      description: '',
      difficulty: Difficulty.beginner,
      daysPerWeek: 99, // deliberately wrong
      estimatedDurationMin: 45,
      days: [
        for (var i = 1; i <= 3; i++)
          ProgramDay(id: 'd$i', name: 'Day $i', exercises: const [
            ProgramExercise(
                exerciseId: 'ex_squat',
                sets: 3,
                repsText: '8-12',
                restSeconds: 90),
          ]),
      ],
    ));

    expect(c.read(customProgramsProvider).single.daysPerWeek, 3);
  });

  test('an empty name falls back to a usable default', () async {
    final c = makeContainer();
    final notifier = c.read(customProgramsProvider.notifier);
    final base = notifier.blank();
    await notifier.save(Program(
      id: base.id,
      name: '   ',
      description: '',
      difficulty: Difficulty.beginner,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: base.days,
    ));
    expect(c.read(customProgramsProvider).single.name, 'My Program');
  });

  test('duplicating a program copies content but not ids', () {
    final c = makeContainer();
    final source = testProgram(id: 'prog_ppl', name: 'Push Pull Legs');
    final copy = c.read(customProgramsProvider.notifier).duplicateOf(source);

    expect(copy.id, isNot(source.id));
    expect(isCustomProgramId(copy.id), isTrue);
    expect(copy.name, contains('Push Pull Legs'));
    expect(copy.days.first.id, isNot(source.days.first.id));
    // Exercises carry over unchanged.
    expect(copy.days.first.exercises.first.exerciseId,
        source.days.first.exercises.first.exerciseId);
  });

  test('editing an existing program overwrites rather than duplicating',
      () async {
    final c = makeContainer();
    final notifier = c.read(customProgramsProvider.notifier);
    final base = notifier.blank();
    final withDay = Program(
      id: base.id,
      name: 'First',
      description: '',
      difficulty: Difficulty.beginner,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: base.days,
    );
    await notifier.save(withDay);
    await notifier.save(Program(
      id: base.id,
      name: 'Renamed',
      description: '',
      difficulty: Difficulty.advanced,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: base.days,
    ));

    final all = c.read(customProgramsProvider);
    expect(all, hasLength(1));
    expect(all.single.name, 'Renamed');
    expect(all.single.difficulty, Difficulty.advanced);
  });

  test('delete removes only the targeted program', () async {
    final c = makeContainer();
    final notifier = c.read(customProgramsProvider.notifier);
    final a = notifier.blank();
    final b = notifier.blank();
    for (final (p, name) in [(a, 'A'), (b, 'B')]) {
      await notifier.save(Program(
        id: p.id,
        name: name,
        description: '',
        difficulty: Difficulty.beginner,
        daysPerWeek: 1,
        estimatedDurationMin: 45,
        days: p.days,
      ));
    }
    expect(c.read(customProgramsProvider), hasLength(2));

    await notifier.delete(a.id);
    final left = c.read(customProgramsProvider);
    expect(left, hasLength(1));
    expect(left.single.name, 'B');
  });

  test("one user's programs are invisible to another", () async {
    final first = makeContainer(userId: 'u1');
    final notifier = first.read(customProgramsProvider.notifier);
    final p = notifier.blank();
    await notifier.save(Program(
      id: p.id,
      name: 'Private',
      description: '',
      difficulty: Difficulty.beginner,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: p.days,
    ));
    expect(first.read(customProgramsProvider), hasLength(1));

    // Same box, different account.
    final second = makeContainer(userId: 'u2');
    expect(second.read(customProgramsProvider), isEmpty);
  });

  test('repository scopes reads by user key', () async {
    final repo = HiveCustomProgramRepository(box);
    final program = testProgram(id: 'custom_x', name: 'X');
    await repo.save('userA', program);

    expect(repo.forUser('userA'), hasLength(1));
    expect(repo.forUser('userB'), isEmpty);
    expect(repo.byId('userA', 'custom_x')?.name, 'X');
    expect(repo.byId('userB', 'custom_x'), isNull);
  });
}
