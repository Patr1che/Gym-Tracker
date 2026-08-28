import '../../../core/models/user_settings.dart';
import '../../../core/sync/sync_state.dart';
import '../domain/settings_repository.dart';

/// Settings are a single row that is always replaced whole, so there is nothing
/// to track per field - one flag is enough to say "push these next time".
class SyncingSettingsRepository implements SettingsRepository {
  SyncingSettingsRepository(this._inner, this._sync);

  final SettingsRepository _inner;
  final SyncState _sync;

  @override
  UserSettings load(String userId) => _inner.load(userId);

  @override
  Future<void> save(String userId, UserSettings settings) async {
    await _inner.save(userId, settings);
    await _sync.markSettingsDirty();
  }
}
