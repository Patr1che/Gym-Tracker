import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/domain/pr_detector.dart';
import '../../../core/domain/streak_calculator.dart';
import '../../../core/models/workout_log.dart';
import '../../../core/providers/app_providers.dart';
import '../../workout_session/presentation/session_controller.dart';

final workoutStreakProvider = Provider<int>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  return StreakCalculator.currentStreak(
    workoutDates: logs.map((l) => l.startedAt),
    today: ref.watch(clockProvider)(),
  );
});

class WeeklyStats {
  const WeeklyStats({
    required this.workouts,
    required this.volumeKg,
    required this.calories,
    required this.durationSec,
  });

  final int workouts;
  final double volumeKg;
  final int calories;
  final int durationSec;
}

/// Stats for the current week, Monday through today.
final weeklyStatsProvider = Provider<WeeklyStats>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  final now = ref.watch(clockProvider)();
  final startOfWeek =
      DateTime(now.year, now.month, now.day - (now.weekday - 1));

  var workouts = 0;
  var volume = 0.0;
  var calories = 0;
  var duration = 0;
  for (final log in logs) {
    if (log.startedAt.isBefore(startOfWeek)) continue;
    workouts++;
    volume += log.totalVolumeKg;
    calories += log.caloriesEst;
    duration += log.durationSec;
  }
  return WeeklyStats(
    workouts: workouts,
    volumeKg: volume,
    calories: calories,
    durationSec: duration,
  );
});

final personalRecordsProvider =
    Provider<Map<String, Map<PrType, PrEntry>>>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  return PrDetector.personalRecords(logs, AppConstants.keyLifts.keys);
});

class ActivityBucket {
  const ActivityBucket({required this.label, required this.count});
  final String label;
  final int count;
}

/// Workout counts per day for the last 7 days (oldest first).
final weeklyActivityProvider = Provider<List<ActivityBucket>>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  final now = ref.watch(clockProvider)();
  const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  return [
    for (var i = 6; i >= 0; i--)
      () {
        final day = DateTime(now.year, now.month, now.day - i);
        final count = logs
            .where((l) =>
                l.startedAt.year == day.year &&
                l.startedAt.month == day.month &&
                l.startedAt.day == day.day)
            .length;
        return ActivityBucket(
            label: dayLabels[day.weekday - 1], count: count);
      }(),
  ];
});

/// Workout counts per month for the last 6 months (oldest first).
final monthlyActivityProvider = Provider<List<ActivityBucket>>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  final now = ref.watch(clockProvider)();
  const monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return [
    for (var i = 5; i >= 0; i--)
      () {
        final month = DateTime(now.year, now.month - i);
        final count = logs
            .where((l) =>
                l.startedAt.year == month.year &&
                l.startedAt.month == month.month)
            .length;
        return ActivityBucket(
            label: monthLabels[month.month - 1], count: count);
      }(),
  ];
});

/// The program day suggested next: the day after the most recent logged one
/// in the user's most-used program, or the first day of a default program.
class TodaysWorkout {
  const TodaysWorkout({
    required this.programId,
    required this.dayId,
    required this.programName,
    required this.dayName,
    required this.exerciseCount,
  });

  final String programId;
  final String dayId;
  final String programName;
  final String dayName;
  final int exerciseCount;
}

/// Last logged workout, for "continue where you left off" surfaces.
final lastWorkoutProvider = Provider<WorkoutLog?>((ref) {
  final logs = ref.watch(workoutLogsProvider);
  return logs.isEmpty ? null : logs.first;
});
