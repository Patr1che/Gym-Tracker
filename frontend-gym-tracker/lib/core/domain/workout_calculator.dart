import '../models/workout_log.dart';

/// Totals over a workout's exercise logs. Only sets that were completed and
/// not skipped count.
abstract final class WorkoutCalculator {
  static double totalVolumeKg(List<ExerciseLog> entries) {
    var volume = 0.0;
    for (final entry in entries) {
      for (final set in entry.sets) {
        if (set.counts) volume += set.weightKg * set.reps;
      }
    }
    return volume;
  }

  static int totalCompletedSets(List<ExerciseLog> entries) {
    var count = 0;
    for (final entry in entries) {
      count += entry.sets.where((s) => s.counts).length;
    }
    return count;
  }

  static int durationSec(DateTime startedAt, DateTime endedAt) {
    final diff = endedAt.difference(startedAt).inSeconds;
    return diff < 0 ? 0 : diff;
  }
}
