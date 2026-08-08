class SetLog {
  const SetLog({
    required this.weightKg,
    required this.reps,
    this.completed = false,
    this.skipped = false,
  });

  final double weightKg;
  final int reps;
  final bool completed;
  final bool skipped;

  bool get counts => completed && !skipped;

  SetLog copyWith({
    double? weightKg,
    int? reps,
    bool? completed,
    bool? skipped,
  }) =>
      SetLog(
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        completed: completed ?? this.completed,
        skipped: skipped ?? this.skipped,
      );

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'reps': reps,
        'completed': completed,
        'skipped': skipped,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? false,
        skipped: json['skipped'] as bool? ?? false,
      );
}

class ExerciseLog {
  const ExerciseLog({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<SetLog> sets;

  ExerciseLog copyWith({List<SetLog>? sets}) =>
      ExerciseLog(exerciseId: exerciseId, sets: sets ?? this.sets);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as List? ?? [])
            .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// A finished workout. Totals are denormalized at finish time so history
/// lists render without recomputation.
class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.userId,
    required this.dayName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.entries,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.caloriesEst,
    this.programId,
  });

  final String id;
  final String userId;
  final String? programId;
  final String dayName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final List<ExerciseLog> entries;
  final double totalVolumeKg;
  final int totalSets;
  final int caloriesEst;

  int get completedExerciseCount =>
      entries.where((e) => e.sets.any((s) => s.counts)).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'programId': programId,
        'dayName': dayName,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationSec': durationSec,
        'entries': entries.map((e) => e.toJson()).toList(),
        'totalVolumeKg': totalVolumeKg,
        'totalSets': totalSets,
        'caloriesEst': caloriesEst,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        programId: json['programId'] as String?,
        dayName: json['dayName'] as String? ?? 'Workout',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime(2020),
        endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
            DateTime(2020),
        durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
        entries: (json['entries'] as List? ?? [])
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0,
        totalSets: (json['totalSets'] as num?)?.toInt() ?? 0,
        caloriesEst: (json['caloriesEst'] as num?)?.toInt() ?? 0,
      );
}
