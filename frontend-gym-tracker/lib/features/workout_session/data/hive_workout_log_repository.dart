import '../../../core/models/workout_log.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/workout_log_repository.dart';

class HiveWorkoutLogRepository implements WorkoutLogRepository {
  HiveWorkoutLogRepository(this._box);

  final JsonBox _box;

  @override
  List<WorkoutLog> forUser(String userId) {
    final logs = _box
        .getAll()
        .map(WorkoutLog.fromJson)
        .where((log) => log.userId == userId)
        .toList();
    logs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return logs;
  }

  @override
  WorkoutLog? byId(String id) {
    final json = _box.get(id);
    return json == null ? null : WorkoutLog.fromJson(json);
  }

  @override
  Future<void> save(WorkoutLog log) => _box.put(log.id, log.toJson());
}
