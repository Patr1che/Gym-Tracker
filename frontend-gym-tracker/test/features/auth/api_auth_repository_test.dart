import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/token_store.dart';
import 'package:gym_tracker/features/auth/data/api_auth_repository.dart';
import 'package:gym_tracker/features/auth/domain/auth_repository.dart';

import '../../helpers/fake_json_box.dart';

/// Fails every call the way a dead connection or a 500 would.
class _FailingApi implements ApiClient {
  _FailingApi(this.error);

  final ApiException error;

  @override
  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) async {
    throw error;
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async => throw error;

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Answers a 401, which is how the API says "wrong email or password".
class _RejectingApi implements ApiClient {
  @override
  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) async {
    throw const ApiException('Invalid email or password', statusCode: 401);
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late FakeJsonBox users;
  late TokenStore tokens;

  setUp(() {
    users = FakeJsonBox();
    tokens = TokenStore();
  });

  group('login', () {
    test('returns null on 401 so the caller can show a credentials message',
        () async {
      final repo = ApiAuthRepository(_RejectingApi(), users, tokens);

      final result =
          await repo.login(email: 'nobody@example.com', password: 'wrongpass');

      expect(result, isNull);
    });

    // The bug this guards: an ApiException escaping here propagated past the
    // controller and past the screen's await, so the sign-in button spun
    // forever with no error shown.
    test('turns a network failure into AuthException, never a raw ApiException',
        () async {
      final repo = ApiAuthRepository(
          _FailingApi(const ApiException('No connection to the server.')),
          users,
          tokens);

      expect(
        () => repo.login(email: 'a@example.com', password: 'secret123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a server error is reported as a failure, not as bad credentials',
        () async {
      final repo = ApiAuthRepository(
          _FailingApi(const ApiException('Something went wrong',
              statusCode: 500)),
          users,
          tokens);

      expect(
        () => repo.login(email: 'a@example.com', password: 'secret123'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('register', () {
    test('turns a network failure into AuthException', () async {
      final repo = ApiAuthRepository(
          _FailingApi(const ApiException('No connection to the server.')),
          users,
          tokens);

      expect(
        () => repo.register(
            name: 'A', email: 'a@example.com', password: 'secret123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a duplicate email surfaces the server message', () async {
      final repo = ApiAuthRepository(
          _FailingApi(const ApiException(
              'An account with this email already exists',
              statusCode: 409)),
          users,
          tokens);

      expect(
        () => repo.register(
            name: 'A', email: 'a@example.com', password: 'secret123'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('already exists'))),
      );
    });
  });
}
