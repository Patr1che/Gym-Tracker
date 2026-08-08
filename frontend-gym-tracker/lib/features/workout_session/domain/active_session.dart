import '../../../core/models/workout_log.dart';

/// One exercise inside a live session. Display fields are denormalized so the
/// session screen never needs repository lookups mid-workout.
class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleToken,
    required this.repsText,
    required this.restSeconds,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final String muscleToken;
  final String repsText;
  final int restSeconds;
  final List<SetLog> sets;

  int get nextSetIndex => sets.indexWhere((s) => !s.completed && !s.skipped);
  bool get isDone => nextSetIndex == -1;

  SessionExercise copyWith({List<SetLog>? sets}) => SessionExercise(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        muscleToken: muscleToken,
        repsText: repsText,
        restSeconds: restSeconds,
        sets: sets ?? this.sets,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleToken': muscleToken,
        'repsText': repsText,
        'restSeconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String? ?? '',
        muscleToken: json['muscleToken'] as String? ?? 'chest',
        repsText: json['repsText'] as String? ?? '8-12',
        restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
        sets: (json['sets'] as List? ?? [])
            .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// The in-progress workout. Snapshotted to Hive on every mutation so a web
/// refresh (or app kill) can resume. The rest timer stores an absolute end
/// timestamp — remaining time is always derived from the clock, never from
/// tick counting, so it survives navigation and browser tab throttling.
class ActiveSessionState {
  const ActiveSessionState({
    required this.userId,
    required this.programId,
    required this.programName,
    required this.dayName,
    required this.startedAt,
    required this.exercises,
    required this.currentIndex,
    this.restEndsAt,
    this.restTotalSeconds = 0,
  });

  final String userId;
  final String? programId;
  final String programName;
  final String dayName;
  final DateTime startedAt;
  final List<SessionExercise> exercises;
  final int currentIndex;
  final DateTime? restEndsAt;
  final int restTotalSeconds;

  SessionExercise get current => exercises[currentIndex];
  bool get resting => restEndsAt != null;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);
  int get completedSets => exercises.fold(
      0, (sum, e) => sum + e.sets.where((s) => s.completed || s.skipped).length);
  bool get allDone => exercises.every((e) => e.isDone);

  ActiveSessionState copyWith({
    List<SessionExercise>? exercises,
    int? currentIndex,
    DateTime? restEndsAt,
    int? restTotalSeconds,
    bool clearRest = false,
  }) =>
      ActiveSessionState(
        userId: userId,
        programId: programId,
        programName: programName,
        dayName: dayName,
        startedAt: startedAt,
        exercises: exercises ?? this.exercises,
        currentIndex: currentIndex ?? this.currentIndex,
        restEndsAt: clearRest ? null : (restEndsAt ?? this.restEndsAt),
        restTotalSeconds:
            clearRest ? 0 : (restTotalSeconds ?? this.restTotalSeconds),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'programId': programId,
        'programName': programName,
        'dayName': dayName,
        'startedAt': startedAt.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'currentIndex': currentIndex,
        'restEndsAt': restEndsAt?.toIso8601String(),
        'restTotalSeconds': restTotalSeconds,
      };

  factory ActiveSessionState.fromJson(Map<String, dynamic> json) =>
      ActiveSessionState(
        userId: json['userId'] as String,
        programId: json['programId'] as String?,
        programName: json['programName'] as String? ?? '',
        dayName: json['dayName'] as String? ?? 'Workout',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime(2020),
        exercises: (json['exercises'] as List? ?? [])
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
        restEndsAt: json['restEndsAt'] == null
            ? null
            : DateTime.tryParse(json['restEndsAt'] as String),
        restTotalSeconds: (json['restTotalSeconds'] as num?)?.toInt() ?? 0,
      );
}
