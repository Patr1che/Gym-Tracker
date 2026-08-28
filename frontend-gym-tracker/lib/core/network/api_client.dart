import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_store.dart';

/// Raised for anything the caller can sensibly show a user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the request never reached the server. The distinction matters:
  /// an offline write stays dirty and retries later, whereas a rejected one
  /// (400, 409) would retry forever.
  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() => message;
}

/// Thin wrapper over Dio that attaches the bearer token and, on a 401, refreshes
/// once and replays the request.
class ApiClient {
  ApiClient({required this.tokens, Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = (baseUrl ?? ApiConfig.baseUrl) + ApiConfig.apiPrefix
      ..connectTimeout = ApiConfig.coldStartTimeout
      ..receiveTimeout = ApiConfig.coldStartTimeout
      ..sendTimeout = ApiConfig.normalTimeout
      ..headers['Content-Type'] = 'application/json'
      // Non-2xx is handled explicitly below rather than thrown as DioException.
      ..validateStatus = (status) => status != null && status < 500;
  }

  final TokenStore tokens;
  final Dio _dio;

  /// Guards against a burst of 401s all refreshing at once and invalidating
  /// each other — refresh tokens rotate, so the second refresh would fail.
  Future<bool>? _inFlightRefresh;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path,
          queryParameters: query, options: _authOptions()));

  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) =>
      _send(() => _dio.post(path,
          data: body, options: _authOptions(authenticated: authenticated)));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body, options: _authOptions()));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body, options: _authOptions()));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete(path, options: _authOptions()));

  Options _authOptions({bool authenticated = true}) {
    final token = tokens.accessToken;
    return Options(headers: {
      if (authenticated && token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw ApiException(_networkMessage(e));
    }

    // Access tokens last 15 minutes, so a 401 on an otherwise valid session is
    // routine. Refresh once and replay; a second 401 means genuinely signed out.
    if (response.statusCode == 401 && tokens.refreshToken != null) {
      if (await _refresh()) {
        try {
          response = await request();
        } on DioException catch (e) {
          throw ApiException(_networkMessage(e));
        }
      }
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return response.data;

    throw ApiException(_serverMessage(response), statusCode: status);
  }

  Future<bool> _refresh() {
    return _inFlightRefresh ??= _performRefresh()
        .whenComplete(() => _inFlightRefresh = null);
  }

  Future<bool> _performRefresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _dio.post('/auth/refresh',
          data: {'refreshToken': refresh},
          options: Options(headers: const {}));
      final data = res.data;
      if (res.statusCode == 200 && data is Map) {
        await tokens.save(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {
      // Fall through - treat as signed out.
    }
    await tokens.clear();
    return false;
  }

  /// The API's error shape is `{"message": "..."}`; fall back to the status.
  static String _serverMessage(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Request failed (${response.statusCode})';
  }

  static String _networkMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'The server took too long to respond. It may be waking up — try again.',
      DioExceptionType.connectionError => 'No connection to the server.',
      _ => 'Could not reach the server.',
    };
  }
}
