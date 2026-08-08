import '../../../core/models/measurement_entry.dart';

abstract interface class MeasurementRepository {
  List<MeasurementEntry> forUser(String userId);
  Future<void> save(MeasurementEntry entry);
  Future<void> delete(String id);
}
