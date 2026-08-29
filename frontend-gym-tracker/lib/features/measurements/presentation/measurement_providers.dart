import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/measurement_entry.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hive_measurement_repository.dart';
import '../data/syncing_measurement_repository.dart';
import '../domain/measurement_repository.dart';

final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  final hive = HiveMeasurementRepository(ref.watch(measurementsBoxProvider));
  if (!ref.watch(syncEnabledProvider)) return hive;
  return SyncingMeasurementRepository(
    hive,
    ref.watch(syncStateProvider),
    ref.watch(clockProvider),
    // Read lazily: syncControllerProvider watches auth, and resolving it during
    // this provider's build would widen the dependency graph for no reason.
    onChanged: () =>
        unawaited(ref.read(syncControllerProvider.notifier).syncNow()),
  );
});

/// Measurement entries for the signed-in user, newest first.
class MeasurementsController extends Notifier<List<MeasurementEntry>> {
  @override
  List<MeasurementEntry> build() {
    final userId =
        ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) return const [];
    return ref.read(measurementRepositoryProvider).forUser(userId);
  }

  Future<void> add(MeasurementEntry entry) async {
    await ref.read(measurementRepositoryProvider).save(entry);
    _reload();
  }

  Future<void> remove(String id) async {
    await ref.read(measurementRepositoryProvider).delete(id);
    _reload();
  }

  void _reload() {
    final userId = ref.read(authControllerProvider).user?.id;
    state = userId == null
        ? const []
        : ref.read(measurementRepositoryProvider).forUser(userId);
  }
}

final measurementsControllerProvider =
    NotifierProvider<MeasurementsController, List<MeasurementEntry>>(
        MeasurementsController.new);

/// Most recent logged body weight, falling back to the onboarding weight.
final currentWeightKgProvider = Provider<double?>((ref) {
  final entries = ref.watch(measurementsControllerProvider);
  for (final entry in entries) {
    if (entry.weightKg != null) return entry.weightKg;
  }
  return ref.watch(
      authControllerProvider.select((a) => a.user?.profile?.weightKg));
});

/// The metrics a user can chart, with accessors over an entry.
enum MetricKind {
  weight('Weight', true),
  bodyFat('Body Fat', false),
  chest('Chest', false),
  waist('Waist', false),
  arms('Arms', false),
  legs('Legs', false),
  shoulders('Shoulders', false),
  neck('Neck', false),
  hips('Hips', false);

  const MetricKind(this.label, this.isWeight);

  final String label;

  /// Weight uses weight units; body fat is a percentage; the rest are lengths.
  final bool isWeight;

  bool get isPercent => this == MetricKind.bodyFat;

  double? read(MeasurementEntry e) => switch (this) {
        MetricKind.weight => e.weightKg,
        MetricKind.bodyFat => e.bodyFatPct,
        MetricKind.chest => e.chestCm,
        MetricKind.waist => e.waistCm,
        MetricKind.arms => e.armsCm,
        MetricKind.legs => e.legsCm,
        MetricKind.shoulders => e.shouldersCm,
        MetricKind.neck => e.neckCm,
        MetricKind.hips => e.hipsCm,
      };
}
