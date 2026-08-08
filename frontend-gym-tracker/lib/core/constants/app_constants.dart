/// App-wide constants. Bump [seedVersion] whenever seed data changes,
/// otherwise existing installs never receive the update.
abstract final class AppConstants {
  static const int seedVersion = 1;

  /// MET value for general strength training — used for calorie estimates.
  static const double strengthTrainingMet = 5.0;

  /// Used when the user has no profile weight yet.
  static const double fallbackWeightKg = 70.0;

  static const int defaultRestSeconds = 90;

  /// Exercise IDs tracked for personal records. These IDs must always exist
  /// in the exercise seed data — never rename them.
  static const Map<String, String> keyLifts = {
    'ex_bench_press': 'Bench Press',
    'ex_squat': 'Squat',
    'ex_deadlift': 'Deadlift',
    'ex_shoulder_press': 'Overhead Press',
    'ex_pull_up': 'Pull Ups',
  };
}
