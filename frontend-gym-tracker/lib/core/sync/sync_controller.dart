import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../network/network_providers.dart';
import 'sync_providers.dart';
import 'sync_service.dart';

/// What the UI can show about sync, if it wants to. Nothing depends on it -
/// sync is deliberately invisible when it works.
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.lastResult,
    this.lastAttempt,
  });

  final bool running;
  final SyncResult? lastResult;
  final DateTime? lastAttempt;

  bool get lastFailed => lastResult?.failed ?? false;
}

/// Drives sync at the points where it is worth doing: once the user is signed
/// in, and after anything that produces new records.
///
/// Failures are swallowed on purpose. Hive is the source of truth, the write
/// already succeeded locally, and the dirty markers survive - so a failed sync
/// is a deferral, not an error the user needs to see.
class SyncController extends Notifier<SyncStatus> {
  Timer? _timer;

  @override
  SyncStatus build() {
    if (!ref.watch(syncEnabledProvider)) return const SyncStatus();

    final userId = ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) {
      _timer?.cancel();
      return const SyncStatus();
    }

    // Signed in: pull immediately, then keep a slow heartbeat so a second
    // device's changes arrive without the user doing anything.
    Future.microtask(() => syncNow());

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    ref.onDispose(() => _timer?.cancel());

    return const SyncStatus();
  }

  /// Safe to call from anywhere; overlapping calls collapse into one request.
  Future<void> syncNow() async {
    if (!ref.read(syncEnabledProvider)) return;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;

    state = SyncStatus(running: true, lastResult: state.lastResult);

    final result = await ref.read(syncServiceProvider).sync(userId);

    state = SyncStatus(lastResult: result, lastAttempt: DateTime.now());

    // Only nudge the UI when the pull actually wrote something, to avoid
    // rebuilding every derived provider on an idle heartbeat.
    if (result.changedAnything) {
      ref.read(syncRevisionProvider.notifier).bump();
    }
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);
