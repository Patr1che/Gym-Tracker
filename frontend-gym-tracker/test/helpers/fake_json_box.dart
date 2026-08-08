import 'dart:convert';

import 'package:gym_tracker/core/persistence/json_box.dart';
import 'package:gym_tracker/features/auth/data/session_store.dart';
import 'package:hive_ce/hive.dart';

/// In-memory stand-in for [JsonBox]. Values round-trip through JSON exactly
/// like the real box, so decoded maps have the same shape.
class FakeJsonBox implements JsonBox {
  final Map<String, String> _store = {};

  @override
  Future<void> put(String key, Map<String, dynamic> value) async =>
      _store[key] = jsonEncode(value);

  @override
  Map<String, dynamic>? get(String key) {
    final raw = _store[key];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  List<Map<String, dynamic>> getAll() => _store.values
      .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
      .toList();

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Iterable<String> get keys => _store.keys;

  @override
  int get length => _store.length;

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Stream<BoxEvent> watch() => const Stream.empty();
}

/// Session store backed by a fixed user id, for controller tests.
class FakeSessionStore implements SessionStore {
  FakeSessionStore({String? userId, bool rememberMe = false})
      : _userId = userId,
        _rememberMe = rememberMe;

  String? _userId;
  bool _rememberMe;

  @override
  String? get currentUserId => _userId;

  @override
  bool get rememberMe => _rememberMe;

  @override
  Future<void> save({required String userId, required bool rememberMe}) async {
    _userId = userId;
    _rememberMe = rememberMe;
  }

  @override
  Future<void> clear() async {
    _userId = null;
    _rememberMe = false;
  }
}
