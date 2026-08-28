import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import '../persistence/hive_boxes_provider.dart';
import 'sync_service.dart';
import 'sync_state.dart';

final syncStateProvider =
    Provider<SyncState>((ref) => SyncState(ref.watch(syncStateBoxProvider)));

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(
      api: ref.watch(apiClientProvider),
      state: ref.watch(syncStateProvider),
      workoutLogs: ref.watch(workoutLogsBoxProvider),
      measurements: ref.watch(measurementsBoxProvider),
      favorites: ref.watch(favoritesBoxProvider),
      settings: ref.watch(settingsBoxProvider),
    ));

/// Bumped after a pull writes anything, so derived providers re-read Hive.
///
/// The app has no reactive box watching - [workoutLogsRevisionProvider] and
/// friends are incremented manually after each write. A pull that skipped this
/// would leave every screen showing stale data until the next local edit.
final syncRevisionProvider = NotifierProvider<SyncRevision, int>(
  SyncRevision.new,
);

class SyncRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
