import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/token_store.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/auth_repository.dart';

/// Server-backed auth, with a local mirror of the signed-in user.
///
/// The mirror is not an optimisation, it is required: [findById] and
/// [findByEmail] are synchronous because the go_router redirect chain and
/// [AuthController.build] both run without awaiting, so they cannot make a
/// network call. Register, login and updateUser hit the API and write the
/// result into the same box the Hive implementation uses, so a restart restores
/// the session offline exactly as before.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._users, this._tokens);

  final ApiClient _api;
  final JsonBox _users;
  final TokenStore _tokens;

  @override
  User? findById(String id) {
    final json = _users.get(id);
    return json == null ? null : User.fromJson(json);
  }

  @override
  User? findByEmail(String email) {
    final needle = email.trim().toLowerCase();
    for (final json in _users.getAll()) {
      if ((json['email'] as String?) == needle) return User.fromJson(json);
    }
    return null;
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final data = await _post('/auth/register', {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      return _acceptSession(data);
    } on ApiException catch (e) {
      // The interface promises AuthException, and callers catch only that.
      // Letting an ApiException escape leaves the caller's spinner running.
      throw AuthException(e.message);
    }
  }

  @override
  Future<User?> login({required String email, required String password}) async {
    try {
      final data = await _post('/auth/login', {
        'email': email.trim().toLowerCase(),
        'password': password,
      });
      return _acceptSession(data);
    } on ApiException catch (e) {
      // 401 is a wrong-credentials answer, which the interface expresses as
      // null. Anything else - offline, 500 - is a real failure and must not be
      // reported to the user as a bad password.
      if (e.statusCode == 401) return null;
      throw AuthException(e.message);
    }
  }

  @override
  Future<User> verifyEmail(String code) async {
    try {
      final data = await _api.post('/auth/verify', body: {'code': code.trim()});
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Unexpected response from the server');
      }
      // The response is the updated user, so the app knows immediately rather
      // than waiting for the next token refresh to notice.
      return _cache(data, data['id'] as String);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> resendVerificationCode() async {
    try {
      await _api.post('/auth/verify/resend');
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> updateUser(User user) async {
    // Only the fields the server owns; credentials are never sent back.
    final profile = user.profile;
    final body = <String, dynamic>{
      'name': user.name,
      if (profile != null) ...{
        'gender': profile.gender.name,
        'age': profile.age,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'goal': profile.goal.name,
        'experience': profile.experience.name,
        'weeklyFrequency': profile.weeklyFrequency,
      },
    };

    // Cache first so onboarding and profile edits feel instant and survive a
    // dropped connection; the server call is what may fail.
    await _users.put(user.id, user.toJson());
    try {
      final data = await _api.patch('/me', body: body);
      if (data is Map<String, dynamic>) await _cache(data, user.id);
    } on ApiException catch (e) {
      // Offline: the local copy stands and the next sync reconciles it.
      if (!e.isNetworkFailure) throw AuthException(e.message);
    }
  }

  /// Not implemented server-side yet.
  ///
  /// The local flow confirmed identity by matching the registered name, which
  /// cannot work against a server - anyone knowing an email and a name could
  /// take the account. The endpoint exists and always returns 202 so it cannot
  /// be used to probe which emails are registered, but no email is delivered
  /// yet, so this reports failure rather than claiming a reset happened.
  @override
  Future<bool> resetPassword({
    required String email,
    required String name,
    required String newPassword,
  }) async {
    try {
      await _api.post('/auth/forgot-password',
          body: {'email': email.trim().toLowerCase()}, authenticated: false);
    } on ApiException {
      // Deliberately ignored - the answer is the same either way.
    }
    return false;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final data = await _api.post(path, body: body, authenticated: false);
    if (data is! Map<String, dynamic>) {
      throw const AuthException('Unexpected response from the server');
    }
    return data;
  }

  /// Stores the token pair and mirrors the returned user locally.
  Future<User> _acceptSession(Map<String, dynamic> data) async {
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const AuthException('Unexpected response from the server');
    }
    return _cache(user, user['id'] as String);
  }

  /// The server never returns credentials, but [User] requires them, so the
  /// local copy carries empty strings. Nothing reads them on this path -
  /// authentication is the server's job now.
  Future<User> _cache(Map<String, dynamic> json, String id) async {
    final existing = _users.get(id);
    final merged = <String, dynamic>{
      ...?existing,
      ...json,
      'passwordHash': '',
      'salt': '',
    };
    await _users.put(id, merged);
    return User.fromJson(merged);
  }
}
