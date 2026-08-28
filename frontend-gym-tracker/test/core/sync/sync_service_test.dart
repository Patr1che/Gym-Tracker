import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/measurement_entry.dart';
import 'package:gym_tracker/core/models/user_settings.dart';
import 'package:gym_tracker/core/models/workout_log.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/sync/sync_service.dart';
import 'package:gym_tracker/core/sync/sync_state.dart';

import '../../helpers/fake_json_box.dart';

/// Stands in for the server. Records what was pushed so the test can assert on
/// the request, and replays a canned response.
class _FakeApi implements ApiClient {
  _FakeApi(this.response);

  Map<String, dynamic> response;
  Map<String, dynamic>? lastRequest;
  int calls = 0;
  ApiException? failWith;

  @override
  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) async {
    calls++;
    lastRequest = body as Map<String, dynamic>?;
    if (failWith != null) throw failWith!;
    return response;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const userId = 'user_1';

  late FakeJsonBox workouts;
  late FakeJsonBox measurements;
  late FakeJsonBox favorites;
  late FakeJsonBox settings;
  late FakeJsonBox syncBox;
  late SyncState state;

  SyncService serviceWith(_FakeApi api) => SyncService(
        api: api,
        state: state,
        workoutLogs: workouts,
        measurements: measurements,
        favorites: favorites,
        settings: settings,
      );

  Map<String, dynamic> emptyResponse() => {
        'serverTime': '2026-08-28T10:00:00.000Z',
        'workouts': <dynamic>[],
        'measurements': <dynamic>[],
        'favorites': <dynamic>[],
      };

  WorkoutLog sampleLog(String id) => WorkoutLog(
        id: id,
        userId: userId,
        dayName: 'Push',
        startedAt: DateTime.utc(2026, 8, 27, 9),
        endedAt: DateTime.utc(2026, 8, 27, 10),
        durationSec: 3600,
        entries: const [
          ExerciseLog(exerciseId: 'ex_bench_press', sets: [
            SetLog(weightKg: 60, reps: 10, completed: true),
          ]),
        ],
        totalVolumeKg: 600,
        totalSets: 1,
        caloriesEst: 350,
      );

  setUp(() {
    workouts = FakeJsonBox();
    measurements = FakeJsonBox();
    favorites = FakeJsonBox();
    settings = FakeJsonBox();
    syncBox = FakeJsonBox();
    state = SyncState(syncBox);
  });

  test('first sync sends a null cursor, meaning send me everything', () async {
    final api = _FakeApi(emptyResponse());

    await serviceWith(api).sync(userId);

    expect(api.lastRequest!['since'], isNull);
  });

  test('a dirty workout is pushed, then cleared once the server accepts it',
      () async {
    await workouts.put('w1', sampleLog('w1').toJson());
    await state.markWorkoutDirty('w1', DateTime.utc(2026, 8, 27, 10));
    final api = _FakeApi(emptyResponse());

    await serviceWith(api).sync(userId);

    final pushed = api.lastRequest!['workouts'] as List;
    expect(pushed, hasLength(1));
    expect(pushed.first['id'], 'w1');
    expect(pushed.first['record']['dayName'], 'Push');
    expect(state.dirtyWorkouts(), isEmpty);
  });

  test('a failed push keeps the record dirty so the next attempt retries it',
      () async {
    await workouts.put('w1', sampleLog('w1').toJson());
    await state.markWorkoutDirty('w1', DateTime.utc(2026, 8, 27, 10));
    final api = _FakeApi(emptyResponse())
      ..failWith = const ApiException('offline');

    final result = await serviceWith(api).sync(userId);

    expect(result.failed, isTrue);
    expect(state.dirtyWorkouts().keys, ['w1']);
    expect(state.cursorFor(userId), isNull, reason: 'cursor must not advance');
  });

  test('a pulled workout lands in Hive and is readable', () async {
    final api = _FakeApi({
      ...emptyResponse(),
      'workouts': [
        {
          'id': 'remote_1',
          'programId': 'prog_ppl',
          'dayName': 'Pull',
          'startedAt': '2026-08-27T09:00:00.000Z',
          'endedAt': '2026-08-27T10:00:00.000Z',
          'durationSec': 3600,
          'entries': [
            {
              'exerciseId': 'ex_deadlift',
              'sets': [
                {'weightKg': 100, 'reps': 5, 'completed': true, 'skipped': false}
              ]
            }
          ],
          'totalVolumeKg': 500,
          'totalSets': 1,
          'caloriesEst': 400,
          'deletedAt': null,
        }
      ],
    });

    final result = await serviceWith(api).sync(userId);

    expect(result.pulled, 1);
    final stored = WorkoutLog.fromJson(workouts.get('remote_1')!);
    expect(stored.dayName, 'Pull');
    expect(stored.userId, userId, reason: 'userId comes from the session');
    expect(stored.entries.single.sets.single.weightKg, 100);
  });

  test('a tombstone removes the local record', () async {
    await workouts.put('w1', sampleLog('w1').toJson());
    final api = _FakeApi({
      ...emptyResponse(),
      'workouts': [
        {'id': 'w1', 'deletedAt': '2026-08-27T11:00:00.000Z'}
      ],
    });

    await serviceWith(api).sync(userId);

    expect(workouts.get('w1'), isNull);
  });

  test('a locally deleted measurement is pushed as a tombstone', () async {
    await measurements.put(
        'm1',
        MeasurementEntry(
          id: 'm1',
          userId: userId,
          date: DateTime.utc(2026, 8, 27),
          weightKg: 80,
        ).toJson());
    await measurements.delete('m1');
    await state.markMeasurementDeleted('m1', DateTime.utc(2026, 8, 27, 12));
    final api = _FakeApi(emptyResponse());

    await serviceWith(api).sync(userId);

    final pushed = api.lastRequest!['measurements'] as List;
    expect(pushed, hasLength(1));
    expect(pushed.first['id'], 'm1');
    expect(pushed.first['deletedAt'], isNotNull);
    expect(state.deletedMeasurements(), isEmpty);
  });

  test('the cursor advances to the server clock, not the device clock',
      () async {
    final api = _FakeApi(emptyResponse());

    await serviceWith(api).sync(userId);

    expect(state.cursorFor(userId), DateTime.utc(2026, 8, 28, 10));
  });

  test('the second sync sends the cursor from the first', () async {
    final api = _FakeApi(emptyResponse());
    final service = serviceWith(api);

    await service.sync(userId);
    await service.sync(userId);

    expect(api.lastRequest!['since'], '2026-08-28T10:00:00.000Z');
  });

  test('favourite tombstones are removed and additions merged', () async {
    await favorites.put(userId, {
      'ids': ['ex_squat', 'ex_bench_press']
    });
    final api = _FakeApi({
      ...emptyResponse(),
      'favorites': [
        {'exerciseId': 'ex_squat', 'deleted': true},
        {'exerciseId': 'ex_deadlift', 'deleted': false},
      ],
    });

    await serviceWith(api).sync(userId);

    expect(favorites.get(userId)!['ids'], ['ex_bench_press', 'ex_deadlift']);
  });

  test('a pull does not overwrite settings that are still waiting to be pushed',
      () async {
    await settings.put(userId, const UserSettings(darkMode: false).toJson());
    await state.markSettingsDirty();
    final api = _FakeApi({
      ...emptyResponse(),
      'settings': const UserSettings(darkMode: true).toJson(),
    });

    await serviceWith(api).sync(userId);

    expect(UserSettings.fromJson(settings.get(userId)!).darkMode, isFalse,
        reason: 'the local edit outranks the server copy until it is pushed');
  });

  test('overlapping syncs collapse into a single request', () async {
    final api = _FakeApi(emptyResponse());
    final service = serviceWith(api);

    await Future.wait([service.sync(userId), service.sync(userId)]);

    expect(api.calls, 1);
  });
}
