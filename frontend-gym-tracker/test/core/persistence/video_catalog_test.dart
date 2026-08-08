import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/youtube_url_parser.dart';
import 'package:gym_tracker/core/persistence/video_catalog.dart';
import 'package:gym_tracker/seed/exercise_seed_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every exercise in the seed data has a video in the catalog',
      () async {
    final catalog = await loadVideoCatalog();
    final seededIds = exerciseSeeds.map((e) => e['id'] as String).toSet();

    final missing = seededIds.difference(catalog.keys.toSet());
    expect(missing, isEmpty,
        reason: 'exercises with no video entry: ${missing.join(', ')}');
  });

  test('the catalog has no entries for exercises that do not exist', () async {
    final catalog = await loadVideoCatalog();
    final seededIds = exerciseSeeds.map((e) => e['id'] as String).toSet();

    final orphans = catalog.keys.toSet().difference(seededIds);
    expect(orphans, isEmpty,
        reason: 'video entries with no matching exercise: '
            '${orphans.join(', ')}');
  });

  test('every link parses to a valid 11-character video id', () async {
    final catalog = await loadVideoCatalog();
    expect(catalog, isNotEmpty);
    for (final entry in catalog.entries) {
      expect(YouTubeUrlParser.isValidId(entry.value), isTrue,
          reason: '${entry.key} produced a bad id: ${entry.value}');
    }
  });

  test('the raw asset is valid JSON and stores full URLs, not bare ids',
      () async {
    final raw =
        await rootBundle.loadString('assets/exercise_videos.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    for (final entry in decoded.entries) {
      if (entry.key.startsWith('_')) continue; // the readme note
      expect(entry.value, isA<String>());
      expect(entry.value as String, contains('youtu'),
          reason: '${entry.key} should hold a YouTube link');
    }
  });

  test('a malformed or unknown link is skipped, not fatal', () {
    // Guards the loader contract used by the asset: bad entries cost one
    // video rather than breaking startup.
    expect(YouTubeUrlParser.extractId('not a link'), isNull);
    expect(YouTubeUrlParser.extractId('https://vimeo.com/12345'), isNull);
  });
}
