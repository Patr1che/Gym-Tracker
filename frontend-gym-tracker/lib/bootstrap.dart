import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/constants/hive_boxes.dart';
import 'core/persistence/json_box.dart';
import 'seed/seeder.dart';

/// Initializes Hive, opens every box, and runs the seeder — all before
/// runApp, so the rest of the app reads boxes synchronously.
Future<void> bootstrap() async {
  await Hive.initFlutter();
  for (final name in HiveBoxes.all) {
    await Hive.openBox<String>(name);
  }
  await runSeeder(
    exercises: JsonBox(Hive.box<String>(HiveBoxes.exercises)),
    programs: JsonBox(Hive.box<String>(HiveBoxes.programs)),
    meta: JsonBox(Hive.box<String>(HiveBoxes.meta)),
  );
}
