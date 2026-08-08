import '../../../core/models/user_settings.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/settings_repository.dart';

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this._box);

  final JsonBox _box;

  @override
  UserSettings load(String userId) {
    final json = _box.get(userId);
    return json == null ? const UserSettings() : UserSettings.fromJson(json);
  }

  @override
  Future<void> save(String userId, UserSettings settings) =>
      _box.put(userId, settings.toJson());
}
