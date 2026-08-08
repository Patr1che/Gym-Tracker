import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../measurements/presentation/log_measurement_sheet.dart';
import '../../measurements/presentation/measurement_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';
import 'dashboard_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startSuggested(
      BuildContext context, WidgetRef ref, SuggestedWorkout suggestion) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    if (controller.hasActiveSession) {
      context.go(Routes.session);
      return;
    }
    controller.start(
      program: suggestion.program,
      day: suggestion.day,
      resolve: ref.read(exerciseRepositoryProvider).byId,
    );
    if (context.mounted) context.go(Routes.session);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final units = ref.watch(unitsProvider);
    final streak = ref.watch(workoutStreakProvider);
    final weekly = ref.watch(weeklyStatsProvider);
    final suggestion = ref.watch(suggestedWorkoutProvider);
    final activeSession = ref.watch(sessionControllerProvider);
    final currentWeight = ref.watch(currentWeightKgProvider);
    final goalDays = user?.profile?.weeklyFrequency ?? 3;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(workoutLogsRevisionProvider.notifier).bump();
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl,
              AppSpacing.screenH, kBottomNavClearance),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        user?.name.split(' ').first ?? 'Athlete',
                        style: Theme.of(context).textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _Avatar(
                  name: user?.name ?? '',
                  onTap: () => context.go(Routes.profile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (activeSession != null) ...[
              _ResumeBanner(
                dayName: activeSession.dayName,
                completedSets: activeSession.completedSets,
                totalSets: activeSession.totalSets,
                onResume: () => context.go(Routes.session),
                onDiscard: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Discard workout?',
                    message: 'Your in-progress workout will be deleted.',
                    confirmLabel: 'Discard',
                    destructive: true,
                  );
                  if (!confirmed) return;
                  await ref
                      .read(sessionControllerProvider.notifier)
                      .abandon();
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (suggestion != null)
              _TodaysWorkoutCard(
                suggestion: suggestion,
                hasActive: activeSession != null,
                onStart: () => _startSuggested(context, ref, suggestion),
                onView: () =>
                    context.go(Routes.programDetail(suggestion.program.id)),
              ),
            const SectionHeader(title: 'This week'),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Day streak',
                    value: '$streak',
                    icon: Icons.local_fire_department_rounded,
                    accent: AppColors.danger,
                    sub: streak > 0 ? 'Keep it going!' : 'Start today',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: 'Calories burned',
                    value: '${weekly.calories}',
                    icon: Icons.bolt_rounded,
                    accent: AppColors.warning,
                    sub: 'estimated',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _WeeklyProgressCard(
              completed: weekly.workouts,
              goal: goalDays,
              volumeLabel:
                  UnitConverter.formatVolume(weekly.volumeKg, units),
              timeLabel: formatDurationText(weekly.durationSec),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Current weight',
                    value: currentWeight == null
                        ? '—'
                        : UnitConverter.formatWeight(currentWeight, units),
                    icon: Icons.monitor_weight_outlined,
                    accent: AppColors.secondary,
                    onTap: () => context.go(Routes.measurements),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: 'Goal',
                    value: user?.profile?.goal.label ?? '—',
                    icon: Icons.flag_rounded,
                    onTap: () => context.go(Routes.editProfile),
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Quick actions'),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.play_arrow_rounded,
                    label: 'Start Workout',
                    onTap: () => suggestion == null
                        ? context.go(Routes.workouts)
                        : _startSuggested(context, ref, suggestion),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.insights_rounded,
                    label: 'View Progress',
                    onTap: () => context.go(Routes.progress),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Log Weight',
                    onTap: () async {
                      final saved = await LogMeasurementSheet.show(context,
                          weightOnly: true);
                      if (saved && context.mounted) {
                        showSuccessSnack(context, 'Weight logged');
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.list_alt_rounded,
                    label: 'View Programs',
                    onTap: () => context.go(Routes.workouts),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.bgDark, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({
    required this.dayName,
    required this.completedSets,
    required this.totalSets,
    required this.onResume,
    required this.onDiscard,
  });

  final String dayName;
  final int completedSets;
  final int totalSets;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: LinearGradient(colors: [
        AppColors.primary.withValues(alpha: 0.20),
        AppColors.secondary.withValues(alpha: 0.10),
      ]),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded,
              size: 36, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workout in progress',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('$dayName · $completedSets/$totalSets sets done',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: onDiscard,
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Discard workout',
          ),
          AppButton(
            label: 'Resume',
            expand: false,
            height: 44,
            onPressed: onResume,
          ),
        ],
      ),
    );
  }
}

class _TodaysWorkoutCard extends StatelessWidget {
  const _TodaysWorkoutCard({
    required this.suggestion,
    required this.hasActive,
    required this.onStart,
    required this.onView,
  });

  final SuggestedWorkout suggestion;
  final bool hasActive;
  final VoidCallback onStart;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text("TODAY'S WORKOUT",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(suggestion.day.name,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            '${suggestion.program.name} · '
            '${suggestion.day.exercises.length} exercises · '
            '~${suggestion.program.estimatedDurationMin} min',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton(
                  label: hasActive ? 'Resume workout' : 'Start Workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onStart,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Details',
                  variant: AppButtonVariant.secondary,
                  onPressed: onView,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.completed,
    required this.goal,
    required this.volumeLabel,
    required this.timeLabel,
  });

  final int completed;
  final int goal;
  final String volumeLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (completed / goal).clamp(0.0, 1.0);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Weekly goal',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('$completed of $goal workouts',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                    icon: Icons.bar_chart_rounded,
                    label: 'Volume',
                    value: volumeLabel),
              ),
              Expanded(
                child: _MiniStat(
                    icon: Icons.timer_outlined,
                    label: 'Time',
                    value: timeLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}
