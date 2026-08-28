import '../../../core/models/workout_log.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/sync/sync_state.dart';
import '../domain/workout_log_repository.dart';

/// Wraps the Hive repository: the local write happens first and returns
/// immediately, then the record is queued for the next push.
///
/// Reads are untouched, so finishing a workout is as instant as it was before
/// the backend existed — no spinner, and it works with no signal.
class SyncingWorkoutLogRepository implements WorkoutLogRepository {
  SyncingWorkoutLogRepository(this._inner, this._sync, this._now);

  final WorkoutLogRepository _inner;
  final SyncState _sync;
  final Clock _now;

  @override
  List<WorkoutLog> forUser(String userId) => _inner.forUser(userId);

  @override
  WorkoutLog? byId(String id) => _inner.byId(id);

  @override
  Future<void> save(WorkoutLog log) async {
    await _inner.save(log);
    await _sync.markWorkoutDirty(log.id, _now());
  }
}
