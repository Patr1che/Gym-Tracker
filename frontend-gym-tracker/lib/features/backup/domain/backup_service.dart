import '../../../core/models/measurement_entry.dart';
import '../../../core/models/user.dart';
import '../../../core/models/user_settings.dart';
import '../../../core/models/workout_log.dart';

/// Bumped when the export shape changes in a way older builds can't read.
const int kBackupFormatVersion = 1;

/// A parsed, validated backup ready to restore.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.profile,
    required this.settings,
    required this.workouts,
    required this.measurements,
    required this.favorites,
  });

  final DateTime exportedAt;
  final UserProfile? profile;
  final UserSettings? settings;
  final List<WorkoutLog> workouts;
  final List<MeasurementEntry> measurements;
  final List<String> favorites;

  int get totalRecords => workouts.length + measurements.length;
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Builds and parses the portable JSON backup.
///
/// Credentials are deliberately excluded: an export is meant to be emailed to
/// yourself or dropped in cloud storage, so it must never carry a password
/// hash or salt.
abstract final class BackupService {
  static Map<String, dynamic> buildExport({
    required User user,
    required UserSettings settings,
    required List<WorkoutLog> workouts,
    required List<MeasurementEntry> measurements,
    required Set<String> favorites,
    required DateTime now,
  }) {
    return {
      'formatVersion': kBackupFormatVersion,
      'app': 'GymTracker',
      'exportedAt': now.toIso8601String(),
      'account': {
        'name': user.name,
        'email': user.email,
        'createdAt': user.createdAt.toIso8601String(),
        // passwordHash and salt intentionally omitted
      },
      'profile': user.profile?.toJson(),
      'settings': settings.toJson(),
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'measurements': measurements.map((m) => m.toJson()).toList(),
      'favorites': favorites.toList()..sort(),
      'counts': {
        'workouts': workouts.length,
        'measurements': measurements.length,
        'favorites': favorites.length,
      },
    };
  }

  /// Throws [BackupException] with a user-readable reason on bad input.
  static BackupData parse(Map<String, dynamic> json) {
    final app = json['app'];
    if (app != null && app != 'GymTracker') {
      throw const BackupException('This file is not a GymTracker backup.');
    }

    final version = (json['formatVersion'] as num?)?.toInt();
    if (version == null) {
      throw const BackupException(
          'This file is missing a format version — it may not be a GymTracker backup.');
    }
    if (version > kBackupFormatVersion) {
      throw BackupException(
          'This backup was made by a newer version of the app '
          '(format $version). Update GymTracker and try again.');
    }

    try {
      return BackupData(
        exportedAt:
            DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        profile: json['profile'] == null
            ? null
            : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        settings: json['settings'] == null
            ? null
            : UserSettings.fromJson(json['settings'] as Map<String, dynamic>),
        workouts: (json['workouts'] as List? ?? [])
            .map((w) => WorkoutLog.fromJson(w as Map<String, dynamic>))
            .toList(),
        measurements: (json['measurements'] as List? ?? [])
            .map((m) => MeasurementEntry.fromJson(m as Map<String, dynamic>))
            .toList(),
        favorites: (json['favorites'] as List? ?? []).cast<String>(),
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
          'This backup file is damaged and could not be read.');
    }
  }

  /// Re-homes imported records onto the signed-in account. IDs are preserved,
  /// so importing the same file twice overwrites rather than duplicates.
  static List<WorkoutLog> reassignWorkouts(
      List<WorkoutLog> workouts, String userId) {
    return workouts
        .map((w) => WorkoutLog(
              id: w.id,
              userId: userId,
              programId: w.programId,
              dayName: w.dayName,
              startedAt: w.startedAt,
              endedAt: w.endedAt,
              durationSec: w.durationSec,
              entries: w.entries,
              totalVolumeKg: w.totalVolumeKg,
              totalSets: w.totalSets,
              caloriesEst: w.caloriesEst,
            ))
        .toList();
  }

  static List<MeasurementEntry> reassignMeasurements(
      List<MeasurementEntry> entries, String userId) {
    return entries
        .map((e) => MeasurementEntry(
              id: e.id,
              userId: userId,
              date: e.date,
              weightKg: e.weightKg,
              bodyFatPct: e.bodyFatPct,
              chestCm: e.chestCm,
              waistCm: e.waistCm,
              armsCm: e.armsCm,
              legsCm: e.legsCm,
              shouldersCm: e.shouldersCm,
              neckCm: e.neckCm,
              hipsCm: e.hipsCm,
            ))
        .toList();
  }

  /// `gymtracker-backup-2026-08-08.json`
  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'gymtracker-backup-'
        '${now.year}-${two(now.month)}-${two(now.day)}.json';
  }
}
