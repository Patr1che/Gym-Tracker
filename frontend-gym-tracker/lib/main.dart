import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/network/network_providers.dart';
import 'core/network/token_store.dart';
import 'core/persistence/video_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  // Read once at startup; editing assets/exercise_videos.json takes effect on
  // the next launch without a rebuild of the seed data.
  final videoCatalog = await loadVideoCatalog();

  // Tokens load before runApp so the request interceptor can stay synchronous
  // and the first sync after launch is already authenticated.
  final tokens = TokenStore();
  await tokens.load();

  runApp(
    ProviderScope(
      overrides: [
        videoCatalogProvider.overrideWithValue(videoCatalog),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const GymTrackerApp(),
    ),
  );
}
