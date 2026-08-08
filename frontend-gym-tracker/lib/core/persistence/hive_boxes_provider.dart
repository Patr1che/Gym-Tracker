import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../constants/hive_boxes.dart';
import 'json_box.dart';

JsonBox _open(String name) => JsonBox(Hive.box<String>(name));

final usersBoxProvider = Provider<JsonBox>((ref) => _open(HiveBoxes.users));
final sessionBoxProvider = Provider<JsonBox>((ref) => _open(HiveBoxes.session));
final settingsBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.settings));
final exercisesBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.exercises));
final programsBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.programs));
final favoritesBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.favorites));
final workoutLogsBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.workoutLogs));
final activeSessionBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.activeSession));
final measurementsBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.measurements));
final exerciseVideosBoxProvider =
    Provider<JsonBox>((ref) => _open(HiveBoxes.exerciseVideos));
final metaBoxProvider = Provider<JsonBox>((ref) => _open(HiveBoxes.meta));
