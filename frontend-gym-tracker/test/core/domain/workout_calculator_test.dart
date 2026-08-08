import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/workout_calculator.dart';
import 'package:gym_tracker/core/models/workout_log.dart';

void main() {
  ExerciseLog log(String id, List<SetLog> sets) =>
      ExerciseLog(exerciseId: id, sets: sets);

  group('totalVolumeKg', () {
    test('sums weight × reps over completed, non-skipped sets', () {
      final entries = [
        log('ex_bench_press', const [
          SetLog(weightKg: 100, reps: 5, completed: true),
          SetLog(weightKg: 100, reps: 5, completed: true),
          SetLog(weightKg: 100, reps: 5), // not completed
          SetLog(weightKg: 100, reps: 5, completed: true, skipped: true),
        ]),
        log('ex_squat', const [
          SetLog(weightKg: 120, reps: 3, completed: true),
        ]),
      ];
      expect(WorkoutCalculator.totalVolumeKg(entries), 100 * 5 * 2 + 120 * 3);
    });

    test('bodyweight sets at 0 kg contribute zero volume', () {
      final entries = [
        log('ex_pull_up', const [
          SetLog(weightKg: 0, reps: 10, completed: true),
        ]),
      ];
      expect(WorkoutCalculator.totalVolumeKg(entries), 0);
    });

    test('empty entries', () {
      expect(WorkoutCalculator.totalVolumeKg([]), 0);
    });
  });

  group('totalCompletedSets', () {
    test('counts only completed, non-skipped sets', () {
      final entries = [
        log('a', const [
          SetLog(weightKg: 10, reps: 10, completed: true),
          SetLog(weightKg: 10, reps: 10, completed: true, skipped: true),
          SetLog(weightKg: 10, reps: 10),
        ]),
      ];
      expect(WorkoutCalculator.totalCompletedSets(entries), 1);
    });
  });

  group('durationSec', () {
    test('positive difference', () {
      final start = DateTime(2026, 1, 1, 10);
      final end = DateTime(2026, 1, 1, 11, 5);
      expect(WorkoutCalculator.durationSec(start, end), 3900);
    });

    test('clamps negative to zero', () {
      final start = DateTime(2026, 1, 1, 10);
      final end = DateTime(2026, 1, 1, 9);
      expect(WorkoutCalculator.durationSec(start, end), 0);
    });
  });
}
