import '../models/workout_log.dart';

enum PrType {
  highestWeight('Highest Weight'),
  highestVolume('Highest Volume'),
  mostReps('Most Reps');

  const PrType(this.label);
  final String label;
}

class PrEntry {
  const PrEntry({
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.date,
  });

  final String exerciseId;
  final PrType type;

  /// kg for weight/volume PRs, rep count for mostReps.
  final double value;
  final DateTime date;
}

/// Personal records are always computed from workout logs on read — never
/// stored — so there is no cache to invalidate.
abstract final class PrDetector {
  /// Best value per (key lift × PR type). Only sets that count are considered.
  static Map<String, Map<PrType, PrEntry>> personalRecords(
    List<WorkoutLog> logs,
    Iterable<String> keyLiftIds,
  ) {
    final tracked = keyLiftIds.toSet();
    final result = <String, Map<PrType, PrEntry>>{};

    void consider(String exerciseId, PrType type, double value, DateTime date) {
      if (value <= 0) return;
      final byType = result.putIfAbsent(exerciseId, () => {});
      final current = byType[type];
      if (current == null || value > current.value) {
        byType[type] = PrEntry(
            exerciseId: exerciseId, type: type, value: value, date: date);
      }
    }

    for (final log in logs) {
      for (final entry in log.entries) {
        if (!tracked.contains(entry.exerciseId)) continue;
        var sessionVolume = 0.0;
        for (final set in entry.sets) {
          if (!set.counts) continue;
          sessionVolume += set.weightKg * set.reps;
          consider(entry.exerciseId, PrType.highestWeight, set.weightKg,
              log.startedAt);
          consider(entry.exerciseId, PrType.mostReps, set.reps.toDouble(),
              log.startedAt);
        }
        consider(entry.exerciseId, PrType.highestVolume, sessionVolume,
            log.startedAt);
      }
    }
    return result;
  }

  /// PRs that [log] just set or broke relative to [previousLogs]
  /// (which must NOT include [log]). Used for the finish-workout celebration.
  static List<PrEntry> newPrsInLog(
    WorkoutLog log,
    List<WorkoutLog> previousLogs,
    Iterable<String> keyLiftIds,
  ) {
    final before = personalRecords(previousLogs, keyLiftIds);
    final after = personalRecords([...previousLogs, log], keyLiftIds);

    final newPrs = <PrEntry>[];
    after.forEach((exerciseId, byType) {
      byType.forEach((type, entry) {
        final previous = before[exerciseId]?[type];
        final isFromThisLog = entry.date == log.startedAt;
        if (isFromThisLog && (previous == null || entry.value > previous.value)) {
          newPrs.add(entry);
        }
      });
    });
    return newPrs;
  }
}
