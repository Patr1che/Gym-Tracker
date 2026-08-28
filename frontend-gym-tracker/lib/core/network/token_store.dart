import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the JWT pair.
///
/// Deliberately not Hive: Hive boxes are plain files (IndexedDB on web) with no
/// encryption, and an access token is a bearer credential — anything that can
/// read it can act as the user until it expires.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'gymtracker.accessToken';
  static const _refreshKey = 'gymtracker.refreshToken';

  final FlutterSecureStorage _storage;

  /// Cached so the request interceptor stays synchronous on the hot path;
  /// secure storage is a platform channel call and is comparatively slow.
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasTokens => _access != null;

  /// Call once during startup, before the first request.
  Future<void> load() async {
    if (_loaded) return;
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (_) {
      // A locked keychain or an unsupported platform must not stop the app —
      // the user simply lands on the login screen.
      _access = null;
      _refresh = null;
    }
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    try {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    } catch (_) {
      // Kept in memory for this session even if persisting failed.
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // Nothing useful to do; the in-memory copy is already gone.
    }
  }
}
