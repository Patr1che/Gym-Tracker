import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'token_store.dart';

/// Created once in bootstrap so tokens are loaded before the first request,
/// then injected here. Overridden in tests with a fake.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // Read lazily inside the callback: authControllerProvider depends on this
    // provider, so resolving it here would be a cycle. By the time a refresh is
    // rejected the graph is long since built.
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).expireSession(),
  ),
);

/// Whether the app talks to the server at all. False falls back to the original
/// local-only behaviour, which is what widget and controller tests get.
final syncEnabledProvider = Provider<bool>((ref) => ApiConfig.syncEnabled);
