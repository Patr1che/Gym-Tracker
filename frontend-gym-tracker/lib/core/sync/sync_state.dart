import '../persistence/json_box.dart';

/// Tracks what still has to reach the server, and how far the last pull got.
///
/// Kept separate from the records themselves so the domain models, their JSON,
/// and the backup format are unchanged by the addition of sync. It also means
/// clearing sync state is a single box wipe rather than a rewrite of every row.
class SyncState {
  SyncState(this._box);

  static const _cursorKey = 'cursor';
  static const _dirtyWorkoutsKey = 'dirty_workouts';
  static const _dirtyMeasurementsKey = 'dirty_measurements';
  static const _deletedMeasurementsKey = 'deleted_measurements';
  static const _dirtyFlagsKey = 'dirty_flags';

  final JsonBox _box;

  // ---------------------------------------------------------------- cursor

  /// Where the last successful pull got to, per user.
  ///
  /// This is the server's clock, never the device's: phone clocks drift, and a
  /// cursor that runs ahead of the server silently skips records forever.
  DateTime? cursorFor(String userId) {
    final raw = _box.get(_cursorKey)?[userId] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setCursor(String userId, DateTime serverTime) =>
      _merge(_cursorKey, {userId: serverTime.toIso8601String()});

  // ----------------------------------------------------------------- dirty

  /// Records written locally that the server has not accepted yet, with the
  /// local write time so the server can reject a stale replay.
  Map<String, DateTime> dirtyWorkouts() => _dirtyMap(_dirtyWorkoutsKey);

  Map<String, DateTime> dirtyMeasurements() => _dirtyMap(_dirtyMeasurementsKey);

  Future<void> markWorkoutDirty(String id, DateTime at) =>
      _merge(_dirtyWorkoutsKey, {id: at.toIso8601String()});

  Future<void> markMeasurementDirty(String id, DateTime at) =>
      _merge(_dirtyMeasurementsKey, {id: at.toIso8601String()});

  /// Ids deleted locally whose tombstone has not reached the server yet.
  ///
  /// The record is already gone from its own box; this is what stops the
  /// deletion being forgotten, which would let the next pull resurrect it.
  Set<String> deletedMeasurements() =>
      (_box.get(_deletedMeasurementsKey)?.keys ?? const <String>[])
          .cast<String>()
          .toSet();

  Future<void> markMeasurementDeleted(String id, DateTime at) async {
    await _merge(_deletedMeasurementsKey, {id: at.toIso8601String()});
    // A deleted record must not also be pushed as an upsert.
    await _removeKeys(_dirtyMeasurementsKey, {id});
  }

  bool get favoritesDirty => _flag('favorites');
  bool get settingsDirty => _flag('settings');

  Future<void> markFavoritesDirty() => _merge(_dirtyFlagsKey, {'favorites': true});
  Future<void> markSettingsDirty() => _merge(_dirtyFlagsKey, {'settings': true});

  // -------------------------------------------------------------- clearing

  /// Called only after the server has confirmed the push. Clearing on send
  /// would lose writes whenever a request fails midway.
  Future<void> clearPushed({
    required Iterable<String> workouts,
    required Iterable<String> measurements,
    required Iterable<String> deletedMeasurements,
    required bool favorites,
    required bool settings,
  }) async {
    await _removeKeys(_dirtyWorkoutsKey, workouts.toSet());
    await _removeKeys(_dirtyMeasurementsKey, measurements.toSet());
    await _removeKeys(_deletedMeasurementsKey, deletedMeasurements.toSet());
    if (favorites) await _removeKeys(_dirtyFlagsKey, {'favorites'});
    if (settings) await _removeKeys(_dirtyFlagsKey, {'settings'});
  }

  /// Used on sign-out, and when a different account signs in on this device.
  Future<void> reset() => _box.clear();

  // --------------------------------------------------------------- helpers

  bool _flag(String name) => _box.get(_dirtyFlagsKey)?[name] == true;

  Map<String, DateTime> _dirtyMap(String key) {
    final raw = _box.get(key) ?? const {};
    final result = <String, DateTime>{};
    raw.forEach((id, value) {
      final at = DateTime.tryParse(value as String? ?? '');
      if (at != null) result[id] = at;
    });
    return result;
  }

  Future<void> _merge(String key, Map<String, dynamic> entries) async {
    final current = _box.get(key) ?? <String, dynamic>{};
    await _box.put(key, {...current, ...entries});
  }

  Future<void> _removeKeys(String key, Set<String> ids) async {
    if (ids.isEmpty) return;
    final current = _box.get(key);
    if (current == null) return;
    final next = Map<String, dynamic>.from(current)
      ..removeWhere((k, _) => ids.contains(k));
    await _box.put(key, next);
  }
}
