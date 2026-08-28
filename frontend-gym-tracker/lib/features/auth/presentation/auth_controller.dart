import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/api_auth_repository.dart';
import '../data/hive_auth_repository.dart';
import '../data/session_store.dart';
import '../domain/auth_repository.dart';

/// Server-backed when sync is on, local-only otherwise. Both implementations
/// mirror the signed-in user into the same box, so the synchronous lookups the
/// router depends on work either way.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final users = ref.watch(usersBoxProvider);
  if (ref.watch(syncEnabledProvider)) {
    return ApiAuthRepository(
      ref.watch(apiClientProvider),
      users,
      ref.watch(tokenStoreProvider),
    );
  }
  return HiveAuthRepository(
    users,
    newId: ref.watch(uuidProvider),
    now: ref.watch(clockProvider),
  );
});

final sessionStoreProvider =
    Provider<SessionStore>((ref) => SessionStore(ref.watch(sessionBoxProvider)));

class AuthState {
  const AuthState({this.user});

  final User? user;

  bool get signedIn => user != null;
  bool get onboarded => user?.profile != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Boxes are pre-opened in bootstrap, so session restore is synchronous.
    final store = ref.read(sessionStoreProvider);
    final userId = store.currentUserId;
    if (store.rememberMe && userId != null) {
      final user = ref.read(authRepositoryProvider).findById(userId);
      return AuthState(user: user);
    }
    return const AuthState();
  }

  /// Returns an error message, or null on success.
  Future<String?> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      // null means the server rejected the credentials; an exception means the
      // request never got an answer. Those are different messages.
      if (user == null) return 'Invalid email or password';
      await ref
          .read(sessionStoreProvider)
          .save(userId: user.id, rememberMe: rememberMe);
      state = AuthState(user: user);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  /// Returns an error message, or null on success. Signs the new user in.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
      await ref
          .read(sessionStoreProvider)
          .save(userId: user.id, rememberMe: true);
      state = AuthState(user: user);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String name,
    required String newPassword,
  }) =>
      ref.read(authRepositoryProvider).resetPassword(
          email: email, name: name, newPassword: newPassword);

  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    if (ref.read(syncEnabledProvider)) {
      // Revoke server-side as well, so a stolen refresh token dies with the
      // session rather than staying valid for its full 30 days.
      final tokens = ref.read(tokenStoreProvider);
      final refresh = tokens.refreshToken;
      if (refresh != null) {
        try {
          await ref
              .read(apiClientProvider)
              .post('/auth/logout', body: {'refreshToken': refresh});
        } catch (_) {
          // Offline logout still clears local tokens; the token expires anyway.
        }
      }
      await tokens.clear();
      // The cursor and dirty markers belong to the account that just left. A
      // different user signing in on this device must start from a full pull,
      // not resume someone else's position.
      await ref.read(syncStateProvider).reset();
    }
    state = const AuthState();
  }

  Future<void> updateUser(User updated) async {
    await ref.read(authRepositoryProvider).updateUser(updated);
    if (state.user?.id == updated.id) state = AuthState(user: updated);
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final user = state.user;
    if (user == null) return;
    await updateUser(user.copyWith(profile: profile));
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
