import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/persistence/video_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  // Read once at startup; editing assets/exercise_videos.json takes effect on
  // the next launch without a rebuild of the seed data.
  final videoCatalog = await loadVideoCatalog();
  runApp(
    ProviderScope(
      overrides: [videoCatalogProvider.overrideWithValue(videoCatalog)],
      child: const GymTrackerApp(),
    ),
  );
}
