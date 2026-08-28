import '../../../core/models/measurement_entry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/sync/sync_state.dart';
import '../domain/measurement_repository.dart';

/// Wraps the Hive repository so writes are queued for the next push.
///
/// Deletes need care. The row is removed locally straight away so the UI
/// updates, but the id is recorded as a pending tombstone: without it, the
/// deletion would exist nowhere the server can learn about, and the next pull
/// would hand the record straight back.
class SyncingMeasurementRepository implements MeasurementRepository {
  SyncingMeasurementRepository(this._inner, this._sync, this._now);

  final MeasurementRepository _inner;
  final SyncState _sync;
  final Clock _now;

  @override
  List<MeasurementEntry> forUser(String userId) => _inner.forUser(userId);

  @override
  Future<void> save(MeasurementEntry entry) async {
    await _inner.save(entry);
    await _sync.markMeasurementDirty(entry.id, _now());
  }

  @override
  Future<void> delete(String id) async {
    await _inner.delete(id);
    await _sync.markMeasurementDeleted(id, _now());
  }
}
