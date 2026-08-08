import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/constants/app_constants.dart';
import 'package:gym_tracker/core/models/exercise.dart';
import 'package:gym_tracker/core/models/program.dart';
import 'package:gym_tracker/core/persistence/json_box.dart';
import 'package:gym_tracker/seed/exercise_seed_data.dart';
import 'package:gym_tracker/seed/program_seed_data.dart';
import 'package:gym_tracker/seed/seeder.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late JsonBox exercises;
  late JsonBox programs;
  late JsonBox meta;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('seeder_test');
    Hive.init(tempDir.path);
    exercises = JsonBox(await Hive.openBox<String>('exercises'));
    programs = JsonBox(await Hive.openBox<String>('programs'));
    meta = JsonBox(await Hive.openBox<String>('meta'));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seed() =>
      runSeeder(exercises: exercises, programs: programs, meta: meta);

  test('seeds all exercises and programs on first run', () async {
    await seed();
    expect(exercises.length, exerciseSeeds.length);
    expect(programs.length, programSeeds.length);
    expect((meta.get('seed')?['version'] as num?)?.toInt(),
        AppConstants.seedVersion);
  });

  test('is idempotent — second run changes nothing', () async {
    await seed();
    final countBefore = exercises.length;
    await seed();
    expect(exercises.length, countBefore);
  });

  test('every seeded map parses into its entity', () async {
    await seed();
    for (final json in exercises.getAll()) {
      final exercise = Exercise.fromJson(json);
      expect(exercise.name, isNotEmpty);
      expect(exercise.tips, isNotEmpty);
      expect(exercise.commonMistakes, isNotEmpty);
    }
    for (final json in programs.getAll()) {
      final program = Program.fromJson(json);
      expect(program.days, isNotEmpty);
    }
  });

  test('program exercise IDs all resolve to seeded exercises', () {
    final ids = exerciseSeeds.map((e) => e['id'] as String).toSet();
    for (final programJson in programSeeds) {
      final program = Program.fromJson(programJson);
      for (final day in program.days) {
        for (final exercise in day.exercises) {
          expect(ids, contains(exercise.exerciseId),
              reason:
                  '${program.name} / ${day.name} references missing exercise '
                  '${exercise.exerciseId}');
        }
      }
    }
  });

  test('key lifts for PR tracking exist in the seed data', () {
    final ids = exerciseSeeds.map((e) => e['id'] as String).toSet();
    for (final keyLift in AppConstants.keyLifts.keys) {
      expect(ids, contains(keyLift));
    }
  });
}
