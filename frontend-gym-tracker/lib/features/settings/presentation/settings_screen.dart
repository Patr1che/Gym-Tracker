import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../shell/presentation/app_shell.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          const SectionHeader(
              title: 'Notifications',
              padding: EdgeInsets.only(bottom: AppSpacing.md)),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  subtitle: 'Allow the app to send you reminders',
                  value: settings.notificationsEnabled,
                  onChanged: (v) => controller
                      .update((s) => s.copyWith(notificationsEnabled: v)),
                ),
                _SwitchRow(
                  icon: Icons.alarm_rounded,
                  label: 'Workout reminder',
                  subtitle: 'Daily nudge at ${settings.reminderTime}',
                  value: settings.workoutRemindersEnabled,
                  enabled: settings.notificationsEnabled,
                  onChanged: (v) => controller
                      .update((s) => s.copyWith(workoutRemindersEnabled: v)),
                ),
                _NavRow(
                  icon: Icons.schedule_rounded,
                  label: 'Reminder time',
                  trailing: settings.reminderTime,
                  enabled: settings.notificationsEnabled &&
                      settings.workoutRemindersEnabled,
                  onTap: () async {
                    final parts = settings.reminderTime.split(':');
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.tryParse(parts.first) ?? 18,
                        minute: int.tryParse(parts.last) ?? 0,
                      ),
                    );
                    if (picked == null) return;
                    final text =
                        '${picked.hour.toString().padLeft(2, '0')}:'
                        '${picked.minute.toString().padLeft(2, '0')}';
                    await controller
                        .update((s) => s.copyWith(reminderTime: text));
                  },
                ),
                _SwitchRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Rest timer sound',
                  subtitle: 'Play a sound when rest ends',
                  value: settings.restTimerSound,
                  isLast: true,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(restTimerSound: v)),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Appearance'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark mode',
                  subtitle: 'Built for the gym floor',
                  value: settings.darkMode,
                  onChanged: controller.setDarkMode,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten_rounded,
                              size: 20,
                              color:
                                  Theme.of(context).colorScheme.onSurface),
                          const SizedBox(width: AppSpacing.lg),
                          Text('Units',
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final unit in Units.values)
                            SelectableChip(
                              label: unit.label,
                              selected: settings.units == unit,
                              onTap: () => controller.setUnits(unit),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _NavRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  trailing: settings.language,
                  isLast: true,
                  onTap: () => showAppSnack(
                      context, 'More languages are coming soon'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Data'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: _NavRow(
              icon: Icons.backup_outlined,
              label: 'Backup & export',
              trailing: 'JSON',
              isLast: true,
              onTap: () => context.go(Routes.backup),
            ),
          ),
          const SectionHeader(title: 'About'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy',
                  onTap: () => context.go(Routes.settingsPage('privacy')),
                ),
                _NavRow(
                  icon: Icons.description_outlined,
                  label: 'Terms',
                  onTap: () => context.go(Routes.settingsPage('terms')),
                ),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About GymTracker',
                  isLast: true,
                  onTap: () => context.go(Routes.settingsPage('about')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            padding: EdgeInsets.zero,
            child: _NavRow(
              icon: Icons.logout_rounded,
              label: 'Log out',
              destructive: true,
              isLast: true,
              onTap: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Log out?',
                  message:
                      'Your data stays on this device. You can sign back in anytime.',
                  confirmLabel: 'Log out',
                  destructive: true,
                );
                if (!confirmed) return;
                await ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text('GymTracker MVP · v1.0.0',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.onSurface),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool enabled;
  final bool destructive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? AppColors.danger : scheme.onSurface;
    return Column(
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: color)),
                  ),
                  if (trailing != null)
                    Text(trailing!,
                        style: Theme.of(context).textTheme.bodySmall),
                  if (!destructive) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
