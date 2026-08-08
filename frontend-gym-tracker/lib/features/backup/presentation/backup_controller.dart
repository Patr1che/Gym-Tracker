import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../measurements/presentation/measurement_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../workout_session/presentation/session_controller.dart';
import '../domain/backup_service.dart';

class ImportSummary {
  const ImportSummary({
    required this.workouts,
    required this.measurements,
    required this.favorites,
    required this.profileRestored,
  });

  final int workouts;
  final int measurements;
  final int favorites;
  final bool profileRestored;
}

class BackupController {
  BackupController(this.ref);

  final Ref ref;

  /// Pretty-printed so the file is readable if opened in a text editor.
  String buildExportJson() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      throw const BackupException('You need to be signed in to export.');
    }
    final map = BackupService.buildExport(
      user: user,
      settings: ref.read(settingsControllerProvider),
      workouts: ref.read(workoutLogsProvider),
      measurements: ref.read(measurementsControllerProvider),
      favorites: ref.read(favoritesControllerProvider),
      now: ref.read(clockProvider)(),
    );
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  String exportFileName() =>
      BackupService.fileName(ref.read(clockProvider)());

  BackupData parse(String jsonText) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(
          'That file is not valid JSON — pick a GymTracker backup file.');
    }
    return BackupService.parse(decoded);
  }

  /// Merges by record id: existing records with the same id are overwritten,
  /// everything else is left alone. Importing the same file twice is a no-op.
  Future<ImportSummary> restore(BackupData data) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      throw const BackupException('You need to be signed in to import.');
    }

    final workouts = BackupService.reassignWorkouts(data.workouts, user.id);
    final logRepo = ref.read(workoutLogRepositoryProvider);
    for (final workout in workouts) {
      await logRepo.save(workout);
    }

    final measurements =
        BackupService.reassignMeasurements(data.measurements, user.id);
    final measurementRepo = ref.read(measurementRepositoryProvider);
    for (final entry in measurements) {
      await measurementRepo.save(entry);
    }

    if (data.favorites.isNotEmpty) {
      final existing = ref.read(favoritesControllerProvider);
      await ref
          .read(favoritesBoxProvider)
          .put(user.id, {'ids': {...existing, ...data.favorites}.toList()});
      ref.invalidate(favoritesControllerProvider);
    }

    if (data.settings != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .update((_) => data.settings!);
    }

    var profileRestored = false;
    if (data.profile != null && user.profile == null) {
      // Only fill an empty profile — never overwrite current onboarding data.
      await ref
          .read(authControllerProvider.notifier)
          .updateUser(user.copyWith(profile: data.profile));
      profileRestored = true;
    }

    ref.read(workoutLogsRevisionProvider.notifier).bump();
    ref.invalidate(measurementsControllerProvider);

    return ImportSummary(
      workouts: workouts.length,
      measurements: measurements.length,
      favorites: data.favorites.length,
      profileRestored: profileRestored,
    );
  }
}

final backupControllerProvider =
    Provider<BackupController>(BackupController.new);
