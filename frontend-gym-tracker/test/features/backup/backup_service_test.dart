import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/models/measurement_entry.dart';
import 'package:gym_tracker/core/models/user_settings.dart';
import 'package:gym_tracker/core/models/workout_log.dart';
import 'package:gym_tracker/features/backup/domain/backup_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  final now = DateTime(2026, 8, 8, 10, 30);

  final workout = WorkoutLog(
    id: 'w1',
    userId: 'u1',
    programId: 'prog_ppl',
    dayName: 'Push',
    startedAt: DateTime(2026, 8, 7, 18),
    endedAt: DateTime(2026, 8, 7, 19),
    durationSec: 3600,
    entries: const [
      ExerciseLog(exerciseId: 'ex_bench_press', sets: [
        SetLog(weightKg: 100, reps: 5, completed: true),
      ]),
    ],
    totalVolumeKg: 500,
    totalSets: 1,
    caloriesEst: 400,
  );

  final measurement = MeasurementEntry(
    id: 'm1',
    userId: 'u1',
    date: DateTime(2026, 8, 1),
    weightKg: 82.5,
    waistCm: 84,
  );

  Map<String, dynamic> export() => BackupService.buildExport(
        user: testUser(),
        settings: const UserSettings(units: Units.imperial, darkMode: false),
        workouts: [workout],
        measurements: [measurement],
        favorites: {'ex_squat', 'ex_bench_press'},
        now: now,
      );

  group('buildExport', () {
    test('never includes credentials', () {
      final json = jsonEncode(export());
      expect(json, isNot(contains('passwordHash')));
      expect(json, isNot(contains('salt')));
      expect(json, isNot(contains(testUser().passwordHash)));
    });

    test('stamps the format version and export time', () {
      final map = export();
      expect(map['formatVersion'], kBackupFormatVersion);
      expect(map['app'], 'GymTracker');
      expect(map['exportedAt'], now.toIso8601String());
    });

    test('includes all user data and a count summary', () {
      final map = export();
      expect(map['workouts'], hasLength(1));
      expect(map['measurements'], hasLength(1));
      expect(map['favorites'], ['ex_bench_press', 'ex_squat']); // sorted
      expect((map['counts'] as Map)['workouts'], 1);
    });

    test('keeps the account name and email for identification', () {
      final account = export()['account'] as Map<String, dynamic>;
      expect(account['email'], 'alex@example.com');
      expect(account['name'], 'Alex Smith');
    });
  });

  group('round trip', () {
    test('export → JSON → parse preserves every field', () {
      final restored =
          BackupService.parse(jsonDecode(jsonEncode(export())) as Map<String, dynamic>);

      expect(restored.exportedAt, now);
      expect(restored.workouts, hasLength(1));
      expect(restored.measurements, hasLength(1));
      expect(restored.favorites, containsAll(['ex_squat', 'ex_bench_press']));

      final w = restored.workouts.single;
      expect(w.id, 'w1');
      expect(w.dayName, 'Push');
      expect(w.totalVolumeKg, 500);
      expect(w.entries.single.sets.single.weightKg, 100);

      final m = restored.measurements.single;
      expect(m.weightKg, 82.5);
      expect(m.waistCm, 84);
      expect(m.bodyFatPct, isNull);

      // Settings survive, including non-default values.
      expect(restored.settings!.units, Units.imperial);
      expect(restored.settings!.darkMode, isFalse);
      expect(restored.profile!.age, 28);
      expect(restored.profile!.goal, FitnessGoal.buildMuscle);
    });
  });

  group('parse rejects bad input', () {
    test('a file from another app', () {
      expect(
        () => BackupService.parse({'app': 'SomethingElse', 'formatVersion': 1}),
        throwsA(isA<BackupException>()),
      );
    });

    test('a file with no format version', () {
      expect(() => BackupService.parse({'workouts': []}),
          throwsA(isA<BackupException>()));
    });

    test('a backup from a newer app version', () {
      expect(
        () => BackupService.parse(
            {'app': 'GymTracker', 'formatVersion': kBackupFormatVersion + 1}),
        throwsA(isA<BackupException>()),
      );
    });

    test('structurally damaged records', () {
      expect(
        () => BackupService.parse({
          'app': 'GymTracker',
          'formatVersion': 1,
          'workouts': [
            {'nonsense': true}
          ],
        }),
        throwsA(isA<BackupException>()),
      );
    });

    test('an empty but valid backup parses to zero records', () {
      final data =
          BackupService.parse({'app': 'GymTracker', 'formatVersion': 1});
      expect(data.totalRecords, 0);
      expect(data.profile, isNull);
      expect(data.settings, isNull);
    });
  });

  group('reassign', () {
    test('re-homes records onto the importing account but keeps ids', () {
      final workouts = BackupService.reassignWorkouts([workout], 'other-user');
      expect(workouts.single.userId, 'other-user');
      expect(workouts.single.id, 'w1'); // id preserved → import is idempotent
      expect(workouts.single.totalVolumeKg, 500);

      final entries =
          BackupService.reassignMeasurements([measurement], 'other-user');
      expect(entries.single.userId, 'other-user');
      expect(entries.single.id, 'm1');
      expect(entries.single.weightKg, 82.5);
    });
  });

  test('fileName is date-stamped and filesystem-safe', () {
    expect(BackupService.fileName(DateTime(2026, 8, 8)),
        'gymtracker-backup-2026-08-08.json');
    expect(BackupService.fileName(DateTime(2026, 12, 25)),
        'gymtracker-backup-2026-12-25.json');
  });
}
