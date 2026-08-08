import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 for local-only credential storage. The abstraction point if
/// a real KDF (or server auth) is introduced later.
abstract final class PasswordHasher {
  static String generateSalt([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  static bool verify(String password, String salt, String expectedHash) =>
      hash(password, salt) == expectedHash;
}
