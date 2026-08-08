import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/workout_log.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';
import '../../../core/domain/unit_converter.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(workoutLogsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(workoutLogsRevisionProvider.notifier).bump();
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: logs.isEmpty
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No workouts yet',
                      message:
                          'Finish your first workout and it will show up here.',
                      actionLabel: 'Browse programs',
                      onAction: () => context.go(Routes.workouts),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                    AppSpacing.xl, AppSpacing.screenH, kBottomNavClearance),
                itemCount: logs.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('History',
                              style:
                                  Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${logs.length} '
                            '${logs.length == 1 ? 'workout' : 'workouts'} logged',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }
                  return _HistoryCard(log: logs[index - 1]);
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: () => context.go(Routes.historyDetail(log.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(log.dayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                formatRelativeDate(log.startedAt, DateTime.now()),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Chip(
                  icon: Icons.schedule_rounded,
                  label: formatDurationText(log.durationSec)),
              const SizedBox(width: AppSpacing.md),
              _Chip(
                  icon: Icons.fitness_center_rounded,
                  label: '${log.completedExerciseCount} exercises'),
              const SizedBox(width: AppSpacing.md),
              _Chip(
                icon: Icons.bar_chart_rounded,
                label: UnitConverter.formatVolume(log.totalVolumeKg, units),
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
