import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../data/hive_auth_repository.dart';
import '../data/session_store.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HiveAuthRepository(
    ref.watch(usersBoxProvider),
    newId: ref.watch(uuidProvider),
    now: ref.watch(clockProvider),
  ),
);

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
    final user = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    if (user == null) return 'Invalid email or password';
    await ref
        .read(sessionStoreProvider)
        .save(userId: user.id, rememberMe: rememberMe);
    state = AuthState(user: user);
    return null;
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
