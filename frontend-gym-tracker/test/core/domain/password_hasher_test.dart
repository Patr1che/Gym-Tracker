import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/password_hasher.dart';

void main() {
  test('hash is deterministic for the same password and salt', () {
    final salt = PasswordHasher.generateSalt(Random(1));
    expect(PasswordHasher.hash('secret123', salt),
        PasswordHasher.hash('secret123', salt));
  });

  test('different salts produce different hashes', () {
    final saltA = PasswordHasher.generateSalt(Random(1));
    final saltB = PasswordHasher.generateSalt(Random(2));
    expect(saltA, isNot(saltB));
    expect(PasswordHasher.hash('secret123', saltA),
        isNot(PasswordHasher.hash('secret123', saltB)));
  });

  test('verify accepts the right password and rejects the wrong one', () {
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash('secret123', salt);
    expect(PasswordHasher.verify('secret123', salt, hash), isTrue);
    expect(PasswordHasher.verify('Secret123', salt, hash), isFalse);
    expect(PasswordHasher.verify('', salt, hash), isFalse);
  });

  test('hash is a 64-char hex sha256 digest', () {
    final hash = PasswordHasher.hash('x', 'salt');
    expect(hash, hasLength(64));
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
  });
}
