import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../measurements/presentation/measurement_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final profile = user?.profile;
    final units = ref.watch(unitsProvider);
    final logs = ref.watch(workoutLogsProvider);
    final streak = ref.watch(workoutStreakProvider);
    final currentWeight = ref.watch(currentWeightKgProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(user?.name ?? ''),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: AppColors.bgDark),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(user?.name ?? 'Athlete',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(user?.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall),
                if (profile != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _Tag(label: profile.goal.label),
                      _Tag(label: profile.experience.label),
                      _Tag(label: '${profile.weeklyFrequency} days/week'),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => context.go(Routes.editProfile),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Workouts',
                  value: '${logs.length}',
                  icon: Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Day streak',
                  value: '$streak',
                  icon: Icons.local_fire_department_rounded,
                  accent: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (profile != null)
            GlassCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Weight',
                    value: UnitConverter.formatWeight(
                        currentWeight ?? profile.weightKg, units),
                  ),
                  _InfoRow(
                    label: 'Height',
                    value: UnitConverter.formatHeight(profile.heightCm, units),
                  ),
                  _InfoRow(label: 'Age', value: '${profile.age}'),
                  _InfoRow(label: 'Gender', value: profile.gender.label),
                  _InfoRow(
                    label: 'Member since',
                    value: user == null
                        ? '—'
                        : formatShortDate(user.createdAt, DateTime.now()),
                    isLast: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.go(Routes.settings),
                ),
                _MenuRow(
                  icon: Icons.straighten_rounded,
                  label: 'Body measurements',
                  onTap: () => context.go(Routes.measurements),
                ),
                _MenuRow(
                  icon: Icons.insights_rounded,
                  label: 'Progress & records',
                  onTap: () => context.go(Routes.progress),
                ),
                _MenuRow(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? AppColors.danger : scheme.onSurface;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
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
                if (!destructive)
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
