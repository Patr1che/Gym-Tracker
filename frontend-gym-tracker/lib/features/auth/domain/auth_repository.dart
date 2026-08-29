import '../../../core/models/user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local-only for the MVP. This interface is the seam where a server-backed
/// implementation slots in later.
abstract interface class AuthRepository {
  User? findById(String id);

  User? findByEmail(String email);

  /// Throws [AuthException] on duplicate email.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  /// Returns null on bad credentials.
  Future<User?> login({required String email, required String password});

  Future<void> updateUser(User user);

  /// Submits the six-digit code mailed at registration and returns the updated
  /// user. Throws [AuthException] with a message worth showing when the code is
  /// wrong, expired, or has been guessed at too many times.
  Future<User> verifyEmail(String code);

  /// Asks for a fresh code. Throws [AuthException] when throttled.
  Future<void> resendVerificationCode();

  /// Local reset: identity is confirmed by matching the registered account
  /// name. Returns false when email or name doesn't match.
  Future<bool> resetPassword({
    required String email,
    required String name,
    required String newPassword,
  });
}
