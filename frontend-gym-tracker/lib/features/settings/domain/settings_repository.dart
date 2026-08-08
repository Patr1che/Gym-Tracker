import '../../../core/models/user_settings.dart';

abstract interface class SettingsRepository {
  UserSettings load(String userId);
  Future<void> save(String userId, UserSettings settings);
}
