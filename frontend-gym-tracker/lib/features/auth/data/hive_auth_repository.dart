import '../../../core/domain/password_hasher.dart';
import '../../../core/models/user.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/auth_repository.dart';

class HiveAuthRepository implements AuthRepository {
  HiveAuthRepository(this._users, {required this.newId, required this.now});

  final JsonBox _users;
  final String Function() newId;
  final DateTime Function() now;

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
    final normalized = email.trim().toLowerCase();
    if (findByEmail(normalized) != null) {
      throw const AuthException('An account with this email already exists');
    }
    final salt = PasswordHasher.generateSalt();
    final user = User(
      id: newId(),
      name: name.trim(),
      email: normalized,
      passwordHash: PasswordHasher.hash(password, salt),
      salt: salt,
      createdAt: now(),
      photoSeed: normalized.hashCode.abs(),
    );
    await _users.put(user.id, user.toJson());
    return user;
  }

  @override
  Future<User?> login({required String email, required String password}) async {
    final user = findByEmail(email);
    if (user == null) return null;
    if (!PasswordHasher.verify(password, user.salt, user.passwordHash)) {
      return null;
    }
    return user;
  }

  /// Local-only builds have no server to confirm against, and User.fromJson
  /// already treats a missing flag as verified, so this path is never reached
  /// from the UI. It fails loudly rather than silently pretending.
  @override
  Future<User> verifyEmail(String code) async =>
      throw const AuthException('Email verification needs a connection.');

  @override
  Future<void> resendVerificationCode() async {}

  @override
  Future<void> updateUser(User user) => _users.put(user.id, user.toJson());

  @override
  Future<bool> resetPassword({
    required String email,
    required String name,
    required String newPassword,
  }) async {
    final user = findByEmail(email);
    if (user == null) return false;
    if (user.name.trim().toLowerCase() != name.trim().toLowerCase()) {
      return false;
    }
    final salt = PasswordHasher.generateSalt();
    await updateUser(user.copyWith(
      salt: salt,
      passwordHash: PasswordHasher.hash(newPassword, salt),
    ));
    return true;
  }
}
