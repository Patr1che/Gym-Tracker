import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_settings.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hive_settings_repository.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => HiveSettingsRepository(ref.watch(settingsBoxProvider)));

/// Per-user settings; falls back to defaults while signed out.
class SettingsController extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    final userId =
        ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) return const UserSettings();
    return ref.read(settingsRepositoryProvider).load(userId);
  }

  Future<void> update(UserSettings Function(UserSettings) change) async {
    final next = change(state);
    state = next;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId != null) {
      await ref.read(settingsRepositoryProvider).save(userId, next);
    }
  }

  Future<void> setUnits(Units units) => update((s) => s.copyWith(units: units));
  Future<void> setDarkMode(bool value) =>
      update((s) => s.copyWith(darkMode: value));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, UserSettings>(SettingsController.new);

/// Watch this everywhere a weight/length is displayed or parsed.
final unitsProvider = Provider<Units>(
    (ref) => ref.watch(settingsControllerProvider.select((s) => s.units)));

final themeModeProvider = Provider<ThemeMode>((ref) =>
    ref.watch(settingsControllerProvider.select((s) => s.darkMode))
        ? ThemeMode.dark
        : ThemeMode.light);
