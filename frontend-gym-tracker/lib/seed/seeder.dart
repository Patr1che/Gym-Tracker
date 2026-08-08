import '../core/constants/app_constants.dart';
import '../core/persistence/json_box.dart';
import 'exercise_seed_data.dart';
import 'program_seed_data.dart';

/// Idempotent, versioned seeding. Upserts by stable ID only when the stored
/// version is behind [AppConstants.seedVersion]; user boxes are never touched.
Future<void> runSeeder({
  required JsonBox exercises,
  required JsonBox programs,
  required JsonBox meta,
}) async {
  final stored = (meta.get('seed')?['version'] as num?)?.toInt() ?? 0;
  if (stored >= AppConstants.seedVersion) return;

  for (final exercise in exerciseSeeds) {
    await exercises.put(exercise['id'] as String, exercise);
  }
  for (final program in programSeeds) {
    await programs.put(program['id'] as String, program);
  }
  await meta.put('seed', {'version': AppConstants.seedVersion});
}
