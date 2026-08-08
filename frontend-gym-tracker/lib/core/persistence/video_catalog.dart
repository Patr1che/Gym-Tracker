import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/youtube_url_parser.dart';

/// Exercise id -> YouTube video id, loaded from `assets/exercise_videos.json`.
///
/// Kept out of the seed data on purpose: editing that JSON changes videos on
/// the next app start, with no Dart change and no seed version bump.
/// Overridden in [main] with the parsed asset; defaults to empty so tests and
/// any non-bootstrapped entry point still work.
final videoCatalogProvider = Provider<Map<String, String>>((ref) => const {});

/// Reads the asset and converts each link to a bare video id.
///
/// Malformed or commented-out entries are skipped rather than throwing — a bad
/// link should cost one video, not stop the app from starting.
Future<Map<String, String>> loadVideoCatalog() async {
  try {
    final raw = await rootBundle.loadString('assets/exercise_videos.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = <String, String>{};
    decoded.forEach((exerciseId, value) {
      if (exerciseId.startsWith('_') || value is! String) return;
      final videoId = YouTubeUrlParser.extractId(value);
      if (videoId != null) catalog[exerciseId] = videoId;
    });
    return catalog;
  } catch (_) {
    return const {};
  }
}
