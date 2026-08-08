import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/pr_detector.dart';
import 'package:gym_tracker/core/models/workout_log.dart';

WorkoutLog makeLog({
  required String id,
  required DateTime date,
  required List<ExerciseLog> entries,
}) =>
    WorkoutLog(
      id: id,
      userId: 'u1',
      dayName: 'Test Day',
      startedAt: date,
      endedAt: date.add(const Duration(hours: 1)),
      durationSec: 3600,
      entries: entries,
      totalVolumeKg: 0,
      totalSets: 0,
      caloriesEst: 0,
    );

const keyLifts = ['ex_bench_press', 'ex_squat'];

void main() {
  group('personalRecords', () {
    test('finds highest weight, session volume, and most reps', () {
      final logs = [
        makeLog(id: 'w1', date: DateTime(2026, 1, 5), entries: [
          const ExerciseLog(exerciseId: 'ex_bench_press', sets: [
            SetLog(weightKg: 100, reps: 5, completed: true),
            SetLog(weightKg: 90, reps: 8, completed: true),
          ]),
        ]),
        makeLog(id: 'w2', date: DateTime(2026, 1, 12), entries: [
          const ExerciseLog(exerciseId: 'ex_bench_press', sets: [
            SetLog(weightKg: 105, reps: 3, completed: true),
          ]),
        ]),
      ];
      final prs = PrDetector.personalRecords(logs, keyLifts);
      final bench = prs['ex_bench_press']!;
      expect(bench[PrType.highestWeight]!.value, 105);
      expect(bench[PrType.highestWeight]!.date, DateTime(2026, 1, 12));
      // Session volume: w1 = 100*5 + 90*8 = 1220 beats w2 = 315.
      expect(bench[PrType.highestVolume]!.value, 1220);
      expect(bench[PrType.mostReps]!.value, 8);
    });

    test('ignores non-key lifts and non-counting sets', () {
      final logs = [
        makeLog(id: 'w1', date: DateTime(2026, 1, 5), entries: [
          const ExerciseLog(exerciseId: 'ex_lat_pulldown', sets: [
            SetLog(weightKg: 70, reps: 10, completed: true),
          ]),
          const ExerciseLog(exerciseId: 'ex_squat', sets: [
            SetLog(weightKg: 140, reps: 5), // never completed
            SetLog(weightKg: 130, reps: 5, completed: true, skipped: true),
          ]),
        ]),
      ];
      final prs = PrDetector.personalRecords(logs, keyLifts);
      expect(prs.containsKey('ex_lat_pulldown'), isFalse);
      expect(prs.containsKey('ex_squat'), isFalse);
    });

    test('empty logs → empty map', () {
      expect(PrDetector.personalRecords([], keyLifts), isEmpty);
    });
  });

  group('newPrsInLog', () {
    final previous = [
      makeLog(id: 'w1', date: DateTime(2026, 1, 5), entries: [
        const ExerciseLog(exerciseId: 'ex_bench_press', sets: [
          SetLog(weightKg: 100, reps: 5, completed: true),
        ]),
      ]),
    ];

    test('first-ever session sets PRs for every type', () {
      final first = previous.single;
      final prs = PrDetector.newPrsInLog(first, [], keyLifts);
      expect(prs.map((p) => p.type).toSet(),
          {PrType.highestWeight, PrType.highestVolume, PrType.mostReps});
    });

    test('heavier single detects a weight PR', () {
      final log = makeLog(id: 'w2', date: DateTime(2026, 1, 12), entries: [
        const ExerciseLog(exerciseId: 'ex_bench_press', sets: [
          SetLog(weightKg: 102.5, reps: 3, completed: true),
        ]),
      ]);
      final prs = PrDetector.newPrsInLog(log, previous, keyLifts);
      expect(prs.any((p) => p.type == PrType.highestWeight), isTrue);
      // 102.5 × 3 = 307.5 < 500, so no volume PR; 3 reps < 5, no rep PR.
      expect(prs.any((p) => p.type == PrType.highestVolume), isFalse);
      expect(prs.any((p) => p.type == PrType.mostReps), isFalse);
    });

    test('tying an existing PR is not a new PR', () {
      final log = makeLog(id: 'w2', date: DateTime(2026, 1, 12), entries: [
        const ExerciseLog(exerciseId: 'ex_bench_press', sets: [
          SetLog(weightKg: 100, reps: 5, completed: true),
        ]),
      ]);
      final prs = PrDetector.newPrsInLog(log, previous, keyLifts);
      expect(prs, isEmpty);
    });
  });
}
