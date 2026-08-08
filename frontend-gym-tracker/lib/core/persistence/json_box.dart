import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// Wraps a `Box<String>` and stores values as JSON strings.
///
/// Storing encoded JSON (instead of raw maps) guarantees decoded values are
/// proper `Map<String, dynamic>` all the way down — Hive's own map storage
/// returns `Map<dynamic, dynamic>` for nested structures, which causes cast
/// errors. The JSON round-trip is also the wire format a future cloud sync
/// will need.
class JsonBox {
  JsonBox(this._box);

  final Box<String> _box;

  Future<void> put(String key, Map<String, dynamic> value) =>
      _box.put(key, jsonEncode(value));

  Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getAll() => _box.values
      .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
      .toList();

  bool containsKey(String key) => _box.containsKey(key);

  Iterable<String> get keys => _box.keys.cast<String>();

  int get length => _box.length;

  Future<void> delete(String key) => _box.delete(key);

  Future<void> clear() => _box.clear();

  Stream<BoxEvent> watch() => _box.watch();
}
