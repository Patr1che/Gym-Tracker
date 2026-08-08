import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/json_box.dart';
import 'package:gym_tracker/features/auth/data/hive_auth_repository.dart';
import 'package:gym_tracker/features/auth/domain/auth_repository.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late JsonBox users;
  late HiveAuthRepository repo;
  var idCounter = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_auth_test');
    Hive.init(tempDir.path);
    users = JsonBox(await Hive.openBox<String>('users'));
    idCounter = 0;
    repo = HiveAuthRepository(
      users,
      newId: () => 'user_${idCounter++}',
      now: () => DateTime(2026, 8, 7, 12),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('register stores a hashed credential, never the password', () async {
    final user = await repo.register(
        name: 'Alex', email: 'Alex@Example.com', password: 'secret123');
    expect(user.email, 'alex@example.com'); // lowercased
    expect(user.passwordHash, isNot(contains('secret123')));
    expect(user.salt, isNotEmpty);
    final raw = users.get(user.id)!;
    expect(raw.toString(), isNot(contains('secret123')));
  });

  test('duplicate email is rejected case-insensitively', () async {
    await repo.register(
        name: 'Alex', email: 'alex@example.com', password: 'secret123');
    expect(
      () => repo.register(
          name: 'Other', email: 'ALEX@example.com', password: 'other1234'),
      throwsA(isA<AuthException>()),
    );
  });

  test('login verifies credentials case-insensitively on email', () async {
    await repo.register(
        name: 'Alex', email: 'alex@example.com', password: 'secret123');
    final ok = await repo.login(
        email: 'Alex@Example.COM', password: 'secret123');
    expect(ok, isNotNull);
    final badPassword =
        await repo.login(email: 'alex@example.com', password: 'wrong1234');
    expect(badPassword, isNull);
    final unknown =
        await repo.login(email: 'nobody@example.com', password: 'secret123');
    expect(unknown, isNull);
  });

  test('resetPassword verifies name, re-salts, and invalidates the old password',
      () async {
    final before = await repo.register(
        name: 'Alex Smith', email: 'alex@example.com', password: 'secret123');

    final wrongName = await repo.resetPassword(
        email: 'alex@example.com', name: 'Someone Else', newPassword: 'new12345');
    expect(wrongName, isFalse);

    final ok = await repo.resetPassword(
        email: 'alex@example.com',
        name: 'alex smith', // case-insensitive
        newPassword: 'new12345');
    expect(ok, isTrue);

    final after = repo.findByEmail('alex@example.com')!;
    expect(after.salt, isNot(before.salt)); // fresh salt
    expect(await repo.login(email: 'alex@example.com', password: 'secret123'),
        isNull);
    expect(await repo.login(email: 'alex@example.com', password: 'new12345'),
        isNotNull);
  });
}
