import '../../../core/models/measurement_entry.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/measurement_repository.dart';

class HiveMeasurementRepository implements MeasurementRepository {
  HiveMeasurementRepository(this._box);

  final JsonBox _box;

  @override
  List<MeasurementEntry> forUser(String userId) {
    final entries = _box
        .getAll()
        .map(MeasurementEntry.fromJson)
        .where((e) => e.userId == userId)
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Future<void> save(MeasurementEntry entry) => _box.put(entry.id, entry.toJson());

  @override
  Future<void> delete(String id) => _box.delete(id);
}
