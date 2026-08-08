import '../../../core/models/workout_log.dart';

abstract interface class WorkoutLogRepository {
  List<WorkoutLog> forUser(String userId);
  WorkoutLog? byId(String id);
  Future<void> save(WorkoutLog log);
}
