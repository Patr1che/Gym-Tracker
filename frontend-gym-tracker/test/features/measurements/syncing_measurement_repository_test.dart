import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/measurement_entry.dart';
import 'package:gym_tracker/core/sync/sync_state.dart';
import 'package:gym_tracker/features/measurements/data/syncing_measurement_repository.dart';
import 'package:gym_tracker/features/measurements/domain/measurement_repository.dart';

import '../../helpers/fake_json_box.dart';

class _InMemoryRepository implements MeasurementRepository {
  final Map<String, MeasurementEntry> saved = {};

  @override
  List<MeasurementEntry> forUser(String userId) =>
      saved.values.where((m) => m.userId == userId).toList();

  @override
  Future<void> save(MeasurementEntry entry) async => saved[entry.id] = entry;

  @override
  Future<void> delete(String id) async => saved.remove(id);
}

void main() {
  late _InMemoryRepository inner;
  late SyncState syncState;
  late int pushes;
  late SyncingMeasurementRepository repo;

  final now = DateTime.utc(2026, 8, 29, 12);

  setUp(() {
    inner = _InMemoryRepository();
    syncState = SyncState(FakeJsonBox());
    pushes = 0;
    repo = SyncingMeasurementRepository(
      inner,
      syncState,
      () => now,
      onChanged: () => pushes++,
    );
  });

  MeasurementEntry entry(String id) =>
      MeasurementEntry(id: id, userId: 'u1', date: now, weightKg: 81.5);

  // The behaviour this guards: a weight logged on one device was only marked
  // dirty, so it sat on that device until the five-minute heartbeat fired - and
  // never left at all if the app was closed first. Other devices could not show
  // it on reload because it had never been pushed.
  test('saving pushes immediately as well as marking dirty', () async {
    await repo.save(entry('m1'));

    expect(pushes, 1);
    expect(syncState.dirtyMeasurements().containsKey('m1'), isTrue);
    expect(inner.saved.containsKey('m1'), isTrue);
  });

  test('deleting pushes immediately and records a tombstone', () async {
    await repo.save(entry('m1'));
    pushes = 0;

    await repo.delete('m1');

    expect(pushes, 1);
    expect(syncState.deletedMeasurements(), contains('m1'));
    expect(inner.saved.containsKey('m1'), isFalse);
  });

  test('the local write still succeeds when no push is wired up', () async {
    final offline = SyncingMeasurementRepository(inner, syncState, () => now);

    await offline.save(entry('m2'));

    expect(inner.saved.containsKey('m2'), isTrue);
  });
}
