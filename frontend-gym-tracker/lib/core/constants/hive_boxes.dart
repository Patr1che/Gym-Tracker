/// Names of all Hive boxes. Every box is opened once in bootstrap() before
/// runApp, so reads are synchronous everywhere else.
abstract final class HiveBoxes {
  static const String users = 'users';
  static const String session = 'session';
  static const String settings = 'settings';
  static const String exercises = 'exercises';
  static const String programs = 'programs';
  static const String favorites = 'favorites';
  static const String workoutLogs = 'workout_logs';
  static const String activeSession = 'active_session';
  static const String measurements = 'measurements';
  static const String exerciseVideos = 'exercise_videos';
  static const String customPrograms = 'custom_programs';
  static const String meta = 'meta';

  static const List<String> all = [
    users,
    session,
    settings,
    exercises,
    programs,
    favorites,
    workoutLogs,
    activeSession,
    measurements,
    exerciseVideos,
    customPrograms,
    meta,
  ];
}
