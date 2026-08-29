import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/token_store.dart';

/// Serves a canned response (or throws) for every request, so a refresh can be
/// made to look rejected, unreachable, or broken on demand.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.refreshStatus, {this.throwOnRefresh});

  final int refreshStatus;
  final DioExceptionType? throwOnRefresh;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, __) async {
    if (options.path.contains('/auth/refresh')) {
      if (throwOnRefresh != null) {
        throw DioException(requestOptions: options, type: throwOnRefresh!);
      }
      return ResponseBody.fromString('{"message":"nope"}', refreshStatus,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    // Everything else 401s, which is what provokes the refresh.
    return ResponseBody.fromString('{"message":"unauthorized"}', 401, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late TokenStore tokens;
  late int expiredCalls;

  setUp(() async {
    tokens = TokenStore();
    await tokens.save(access: 'stale-access', refresh: 'the-refresh');
    expiredCalls = 0;
  });

  ApiClient clientFor(_StubAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(
      tokens: tokens,
      dio: dio,
      baseUrl: 'http://stub.invalid',
      onSessionExpired: () => expiredCalls++,
    );
  }

  test('a rejected refresh token ends the session', () async {
    final client = clientFor(_StubAdapter(401));

    await expectLater(() => client.get('/sync'), throwsA(isA<ApiException>()));

    expect(expiredCalls, 1);
    expect(tokens.refreshToken, isNull);
  });

  // The important half. Sync fails routinely - no signal, a suspended free
  // instance, a cold start - and none of it means the session ended. Signing
  // the user out here would strand them outside their own offline data at the
  // one moment they cannot reach the server to get back in.
  test('an unreachable server never ends the session', () async {
    final client = clientFor(
        _StubAdapter(0, throwOnRefresh: DioExceptionType.connectionError));

    await expectLater(() => client.get('/sync'), throwsA(isA<ApiException>()));

    expect(expiredCalls, 0);
    expect(tokens.refreshToken, 'the-refresh');
  });

  test('a 500 from the refresh endpoint never ends the session', () async {
    final client = clientFor(_StubAdapter(500));

    await expectLater(() => client.get('/sync'), throwsA(isA<ApiException>()));

    expect(expiredCalls, 0);
    expect(tokens.refreshToken, 'the-refresh');
  });
}
