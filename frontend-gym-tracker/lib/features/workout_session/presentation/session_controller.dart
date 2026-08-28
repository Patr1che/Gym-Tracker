import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/domain/calorie_calculator.dart';
import '../../../core/domain/pr_detector.dart';
import '../../../core/domain/workout_calculator.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/program.dart';
import '../../../core/models/workout_log.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/hive_workout_log_repository.dart';
import '../data/syncing_workout_log_repository.dart';
import '../domain/active_session.dart';
import '../domain/workout_log_repository.dart';

final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>((ref) {
  final hive = HiveWorkoutLogRepository(ref.watch(workoutLogsBoxProvider));
  if (!ref.watch(syncEnabledProvider)) return hive;
  return SyncingWorkoutLogRepository(
    hive,
    ref.watch(syncStateProvider),
    ref.watch(clockProvider),
  );
});

/// Bumped whenever a workout log is written, so derived providers re-read.
class WorkoutLogsRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final workoutLogsRevisionProvider =
    NotifierProvider<WorkoutLogsRevision, int>(WorkoutLogsRevision.new);

/// All workout logs for the signed-in user, newest first.
final workoutLogsProvider = Provider<List<WorkoutLog>>((ref) {
  ref.watch(workoutLogsRevisionProvider);
  // A sync pull writes straight into Hive, so history has to re-read on that
  // signal too - otherwise pulled workouts stay invisible until the next local
  // write happens to bump the revision.
  ref.watch(syncRevisionProvider);
  final userId = ref.watch(authControllerProvider.select((a) => a.user?.id));
  if (userId == null) return const [];
  return ref.watch(workoutLogRepositoryProvider).forUser(userId);
});

/// Result surfaced by the finish-workout summary sheet.
class SessionSummary {
  const SessionSummary({required this.log, required this.newPrs});

  final WorkoutLog log;
  final List<PrEntry> newPrs;
}

/// Root-scoped (non-autodispose) so the workout and its rest timer survive
/// navigation. Every mutation snapshots to Hive so a web refresh resumes.
class SessionController extends Notifier<ActiveSessionState?> {
  Timer? _ticker;

  @override
  ActiveSessionState? build() {
    ref.onDispose(() => _ticker?.cancel());
    final userId =
        ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) {
      _ticker?.cancel();
      return null;
    }
    final snapshot = ref.read(activeSessionBoxProvider).get(userId);
    if (snapshot == null) return null;
    final restored = ActiveSessionState.fromJson(snapshot);
    if (restored.restEndsAt != null) _ensureTicker();
    return restored;
  }

  DateTime get _now => ref.read(clockProvider)();

  /// Builds a fresh session from a program day. Overwrites any existing
  /// session — callers confirm with the user first via [hasActiveSession].
  void start({
    required Program program,
    required ProgramDay day,
    required Exercise? Function(String id) resolve,
  }) {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;

    final exercises = <SessionExercise>[];
    for (final programExercise in day.exercises) {
      final exercise = resolve(programExercise.exerciseId);
      exercises.add(SessionExercise(
        exerciseId: programExercise.exerciseId,
        exerciseName: exercise?.name ?? programExercise.exerciseId,
        muscleToken: exercise?.imagePlaceholder ?? 'chest',
        repsText: programExercise.repsText,
        restSeconds: programExercise.restSeconds,
        sets: List.generate(
          programExercise.sets,
          (_) => SetLog(
            weightKg: 0,
            reps: _defaultReps(programExercise.repsText),
          ),
        ),
      ));
    }

    _ticker?.cancel();
    _set(ActiveSessionState(
      userId: userId,
      programId: program.id,
      programName: program.name,
      dayName: day.name,
      startedAt: _now,
      exercises: exercises,
      currentIndex: 0,
    ));
  }

  bool get hasActiveSession => state != null;

  /// Lower bound of a '8-12'-style target, used to prefill the reps input.
  static int _defaultReps(String repsText) {
    final match = RegExp(r'\d+').firstMatch(repsText);
    return match == null ? 10 : int.parse(match.group(0)!);
  }

  void updateCurrentSet({double? weightKg, int? reps}) {
    final session = state;
    if (session == null) return;
    final exercise = session.current;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == -1) return;
    final sets = [...exercise.sets];
    sets[setIndex] = sets[setIndex].copyWith(weightKg: weightKg, reps: reps);
    _replaceCurrentExercise(session, exercise.copyWith(sets: sets));
  }

  void completeSet() {
    final session = state;
    if (session == null) return;
    final exercise = session.current;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == -1) return;
    final sets = [...exercise.sets];
    final done = sets[setIndex].copyWith(completed: true);
    sets[setIndex] = done;
    // Carry the load forward: the sets still to come start from what was
    // just lifted rather than an empty field. They stay editable, and
    // completing an edited set carries the new numbers on from there.
    for (var i = setIndex + 1; i < sets.length; i++) {
      if (sets[i].completed || sets[i].skipped) continue;
      sets[i] = sets[i].copyWith(weightKg: done.weightKg, reps: done.reps);
    }
    final updated = exercise.copyWith(sets: sets);

    var next = _withExercise(session, updated);
    // Rest after every completed set except the very last one of the workout.
    if (!next.allDone) {
      next = next.copyWith(
        restEndsAt: _now.add(Duration(seconds: exercise.restSeconds)),
        restTotalSeconds: exercise.restSeconds,
      );
      _ensureTicker();
    }
    // When the exercise is finished, auto-advance to the next unfinished one.
    if (updated.isDone) {
      final nextIndex = _nextUnfinishedIndex(next);
      if (nextIndex != null) next = next.copyWith(currentIndex: nextIndex);
    }
    _set(next);
  }

  void skipSet() {
    final session = state;
    if (session == null) return;
    final exercise = session.current;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == -1) return;
    final sets = [...exercise.sets];
    sets[setIndex] = sets[setIndex].copyWith(skipped: true, completed: false);
    final updated = exercise.copyWith(sets: sets);
    var next = _withExercise(session, updated);
    if (updated.isDone) {
      final nextIndex = _nextUnfinishedIndex(next);
      if (nextIndex != null) next = next.copyWith(currentIndex: nextIndex);
    }
    _set(next);
  }

  void goToExercise(int index) {
    final session = state;
    if (session == null) return;
    final clamped = index.clamp(0, session.exercises.length - 1);
    _set(session.copyWith(currentIndex: clamped));
  }

  void nextExercise() => goToExercise((state?.currentIndex ?? 0) + 1);

  void previousExercise() => goToExercise((state?.currentIndex ?? 0) - 1);

  void skipRest() {
    final session = state;
    if (session == null || session.restEndsAt == null) return;
    _ticker?.cancel();
    _set(session.copyWith(clearRest: true));
  }

  void extendRest([int seconds = 30]) {
    final session = state;
    final endsAt = session?.restEndsAt;
    if (session == null || endsAt == null) return;
    final base = endsAt.isAfter(_now) ? endsAt : _now;
    _set(session.copyWith(
      restEndsAt: base.add(Duration(seconds: seconds)),
      restTotalSeconds: session.restTotalSeconds + seconds,
    ));
  }

  int get restRemainingSeconds {
    final endsAt = state?.restEndsAt;
    if (endsAt == null) return 0;
    final remaining = endsAt.difference(_now).inMilliseconds;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  Future<void> abandon() async {
    _ticker?.cancel();
    final userId = state?.userId;
    state = null;
    if (userId != null) {
      await ref.read(activeSessionBoxProvider).delete(userId);
    }
  }

  /// Saves the workout log and clears the session. Returns the summary for
  /// the celebration sheet.
  Future<SessionSummary?> finish() async {
    final session = state;
    if (session == null) return null;
    _ticker?.cancel();

    final endedAt = _now;
    final entries = session.exercises
        .map((e) => ExerciseLog(exerciseId: e.exerciseId, sets: e.sets))
        .where((e) => e.sets.any((s) => s.counts))
        .toList();
    final durationSec =
        WorkoutCalculator.durationSec(session.startedAt, endedAt);
    final profileWeight =
        ref.read(authControllerProvider).user?.profile?.weightKg;

    final log = WorkoutLog(
      id: ref.read(uuidProvider)(),
      userId: session.userId,
      programId: session.programId,
      dayName: session.dayName,
      startedAt: session.startedAt,
      endedAt: endedAt,
      durationSec: durationSec,
      entries: entries,
      totalVolumeKg: WorkoutCalculator.totalVolumeKg(entries),
      totalSets: WorkoutCalculator.totalCompletedSets(entries),
      caloriesEst: CalorieCalculator.estimate(
          durationSec: durationSec, weightKg: profileWeight),
    );

    final previousLogs = ref.read(workoutLogsProvider);
    final newPrs =
        PrDetector.newPrsInLog(log, previousLogs, AppConstants.keyLifts.keys);

    await ref.read(workoutLogRepositoryProvider).save(log);
    state = null;
    await ref.read(activeSessionBoxProvider).delete(session.userId);
    ref.read(workoutLogsRevisionProvider.notifier).bump();

    // Finishing a workout is the moment worth pushing: it is the record the
    // user most wants safe. Not awaited - the summary sheet must appear
    // immediately, and a failed push simply stays queued.
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());

    return SessionSummary(log: log, newPrs: newPrs);
  }

  // ---- internals ----

  int? _nextUnfinishedIndex(ActiveSessionState session) {
    final count = session.exercises.length;
    // Search forward from the current exercise first, then wrap.
    for (var offset = 1; offset <= count; offset++) {
      final index = (session.currentIndex + offset) % count;
      if (!session.exercises[index].isDone) return index;
    }
    return null;
  }

  ActiveSessionState _withExercise(
      ActiveSessionState session, SessionExercise updated) {
    final exercises = [...session.exercises];
    exercises[session.currentIndex] = updated;
    return session.copyWith(exercises: exercises);
  }

  void _replaceCurrentExercise(
          ActiveSessionState session, SessionExercise updated) =>
      _set(_withExercise(session, updated));

  void _set(ActiveSessionState next) {
    state = next;
    ref.read(activeSessionBoxProvider).put(next.userId, next.toJson());
  }

  void _ensureTicker() {
    _ticker?.cancel();
    // Wall-clock math keeps the countdown correct even if the browser
    // throttles this timer — ticks only refresh the UI.
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final session = state;
      final endsAt = session?.restEndsAt;
      if (session == null || endsAt == null) {
        _ticker?.cancel();
        return;
      }
      if (!_now.isBefore(endsAt)) {
        _ticker?.cancel();
        if (ref.read(settingsControllerProvider).restTimerSound) {
          SystemSound.play(SystemSoundType.alert);
        }
        HapticFeedback.mediumImpact();
        _set(session.copyWith(clearRest: true));
      } else {
        // New instance each tick so listeners repaint the countdown.
        state = session.copyWith();
      }
    });
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, ActiveSessionState?>(
        SessionController.new);
