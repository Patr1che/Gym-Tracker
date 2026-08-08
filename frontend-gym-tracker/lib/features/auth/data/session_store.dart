import '../../../core/persistence/json_box.dart';

/// Persists the signed-in user across launches. The user id is stored either
/// way; auto-restore on startup only happens when rememberMe is true.
class SessionStore {
  SessionStore(this._box);

  static const _key = 'state';
  final JsonBox _box;

  String? get currentUserId => _box.get(_key)?['currentUserId'] as String?;

  bool get rememberMe => _box.get(_key)?['rememberMe'] as bool? ?? false;

  Future<void> save({required String userId, required bool rememberMe}) =>
      _box.put(_key, {'currentUserId': userId, 'rememberMe': rememberMe});

  Future<void> clear() => _box.delete(_key);
}
