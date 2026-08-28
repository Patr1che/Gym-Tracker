import '../models/measurement_entry.dart';
import '../models/user_settings.dart';
import '../models/workout_log.dart';
import '../network/api_client.dart';
import '../persistence/json_box.dart';
import 'sync_state.dart';

/// What a sync run did, for the caller to report or ignore.
class SyncResult {
  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.failed = false,
    this.message,
  });

  final int pushed;
  final int pulled;
  final bool failed;
  final String? message;

  bool get changedAnything => pulled > 0;
}

/// Push everything dirty, pull everything changed since the cursor, in one round
/// trip.
///
/// Runs opportunistically: a failure is never surfaced as an error the user has
/// to deal with, because the local database is authoritative and nothing was
/// lost. Dirty markers survive so the next attempt retries them.
class SyncService {
  SyncService({
    required ApiClient api,
    required SyncState state,
    required JsonBox workoutLogs,
    required JsonBox measurements,
    required JsonBox favorites,
    required JsonBox settings,
  })  : _api = api,
        _state = state,
        _workoutLogs = workoutLogs,
        _measurements = measurements,
        _favorites = favorites,
        _settings = settings;

  final ApiClient _api;
  final SyncState _state;
  final JsonBox _workoutLogs;
  final JsonBox _measurements;
  final JsonBox _favorites;
  final JsonBox _settings;

  /// Guards against overlapping runs - startup, resume and a finished workout
  /// can easily fire at once, and two pushes of the same record would race.
  Future<SyncResult>? _inFlight;

  Future<SyncResult> sync(String userId) =>
      _inFlight ??= _run(userId).whenComplete(() => _inFlight = null);

  Future<SyncResult> _run(String userId) async {
    final dirtyWorkouts = _state.dirtyWorkouts();
    final dirtyMeasurements = _state.dirtyMeasurements();
    final deletedMeasurements = _state.deletedMeasurements();
    final favoritesDirty = _state.favoritesDirty;
    final settingsDirty = _state.settingsDirty;

    final request = <String, dynamic>{
      'since': _state.cursorFor(userId)?.toUtc().toIso8601String(),
      'workouts': _workoutPushes(userId, dirtyWorkouts),
      'measurements': [
        ..._measurementPushes(userId, dirtyMeasurements),
        // A tombstone carries only the id; the record is already gone locally.
        for (final id in deletedMeasurements)
          {'id': id, 'deletedAt': DateTime.now().toUtc().toIso8601String()},
      ],
      if (favoritesDirty) 'favorites': _localFavorites(userId),
      if (settingsDirty) 'settings': _localSettings(userId).toJson(),
    };

    final Map<String, dynamic> response;
    try {
      final data = await _api.post('/sync', body: request);
      if (data is! Map<String, dynamic>) {
        return const SyncResult(failed: true, message: 'Unexpected sync response');
      }
      response = data;
    } on ApiException catch (e) {
      // Nothing is cleared, so every dirty record is retried next time.
      return SyncResult(failed: true, message: e.message);
    }

    final pulled = await _applyResponse(userId, response);

    await _state.clearPushed(
      workouts: dirtyWorkouts.keys,
      measurements: dirtyMeasurements.keys,
      deletedMeasurements: deletedMeasurements,
      favorites: favoritesDirty,
      settings: settingsDirty,
    );

    final serverTime = DateTime.tryParse(response['serverTime'] as String? ?? '');
    if (serverTime != null) await _state.setCursor(userId, serverTime);

    return SyncResult(
      pushed: dirtyWorkouts.length +
          dirtyMeasurements.length +
          deletedMeasurements.length,
      pulled: pulled,
    );
  }

  // ------------------------------------------------------------------ push

  List<Map<String, dynamic>> _workoutPushes(
      String userId, Map<String, DateTime> dirty) {
    final pushes = <Map<String, dynamic>>[];
    for (final entry in dirty.entries) {
      final json = _workoutLogs.get(entry.key);
      if (json == null) continue; // Deleted locally before it ever synced.
      final log = WorkoutLog.fromJson(json);
      if (log.userId != userId) continue;
      pushes.add({
        'id': log.id,
        'record': {
          'programId': log.programId,
          'dayName': log.dayName,
          'startedAt': log.startedAt.toUtc().toIso8601String(),
          'endedAt': log.endedAt.toUtc().toIso8601String(),
          'entries': log.entries.map((e) => e.toJson()).toList(),
          'updatedAt': entry.value.toUtc().toIso8601String(),
        },
      });
    }
    return pushes;
  }

  List<Map<String, dynamic>> _measurementPushes(
      String userId, Map<String, DateTime> dirty) {
    final pushes = <Map<String, dynamic>>[];
    for (final entry in dirty.entries) {
      final json = _measurements.get(entry.key);
      if (json == null) continue;
      final m = MeasurementEntry.fromJson(json);
      if (m.userId != userId) continue;
      pushes.add({
        'id': m.id,
        'record': {
          'date': m.date.toUtc().toIso8601String(),
          'weightKg': m.weightKg,
          'bodyFatPct': m.bodyFatPct,
          'chestCm': m.chestCm,
          'waistCm': m.waistCm,
          'armsCm': m.armsCm,
          'legsCm': m.legsCm,
          'shouldersCm': m.shouldersCm,
          'neckCm': m.neckCm,
          'hipsCm': m.hipsCm,
          'updatedAt': entry.value.toUtc().toIso8601String(),
        },
      });
    }
    return pushes;
  }

  List<String> _localFavorites(String userId) =>
      ((_favorites.get(userId)?['ids'] as List?)?.cast<String>() ?? const [])
        ..sort();

  UserSettings _localSettings(String userId) {
    final json = _settings.get(userId);
    return json == null ? const UserSettings() : UserSettings.fromJson(json);
  }

  // ------------------------------------------------------------------ pull

  Future<int> _applyResponse(
      String userId, Map<String, dynamic> response) async {
    var pulled = 0;

    for (final raw in (response['workouts'] as List? ?? const [])) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null) continue;
      if (json['deletedAt'] != null) {
        // A tombstone. Deleting an id we never had is harmless.
        await _workoutLogs.delete(id);
      } else {
        await _workoutLogs.put(id, _workoutFromServer(json, userId));
      }
      pulled++;
    }

    for (final raw in (response['measurements'] as List? ?? const [])) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null) continue;
      if (json['deletedAt'] != null) {
        await _measurements.delete(id);
      } else {
        await _measurements.put(id, _measurementFromServer(json, userId));
      }
      pulled++;
    }

    // Favourites arrive as the changed set including tombstones, so they are
    // merged into what is already stored rather than replacing it.
    final favorites = response['favorites'] as List?;
    if (favorites != null && favorites.isNotEmpty) {
      final current = _localFavorites(userId).toSet();
      for (final raw in favorites) {
        final json = raw as Map<String, dynamic>;
        final exerciseId = json['exerciseId'] as String?;
        if (exerciseId == null) continue;
        if (json['deleted'] == true) {
          current.remove(exerciseId);
        } else {
          current.add(exerciseId);
        }
      }
      await _favorites.put(userId, {'ids': current.toList()..sort()});
      pulled++;
    }

    final settings = response['settings'] as Map<String, dynamic>?;
    if (settings != null && !_state.settingsDirty) {
      // Skipped when a local edit is still queued, so the pull cannot undo a
      // change the user just made.
      await _settings.put(userId, UserSettings.fromJson(settings).toJson());
    }

    return pulled;
  }

  /// The server owns userId (from the JWT) and the recomputed totals; the local
  /// shape needs userId filled in explicitly.
  Map<String, dynamic> _workoutFromServer(
          Map<String, dynamic> json, String userId) =>
      {...json, 'userId': userId}..remove('deletedAt');

  Map<String, dynamic> _measurementFromServer(
          Map<String, dynamic> json, String userId) =>
      {...json, 'userId': userId}..remove('deletedAt');
}
