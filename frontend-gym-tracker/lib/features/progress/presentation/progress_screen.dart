import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/domain/pr_detector.dart';
import '../../../core/domain/unit_converter.dart';
import '../../../core/models/enums.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bar_chart_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/line_chart_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../measurements/presentation/measurement_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';
import 'progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(workoutLogsProvider);
    final units = ref.watch(unitsProvider);
    final measurements = ref.watch(measurementsControllerProvider);
    final streak = ref.watch(workoutStreakProvider);
    final weekly = ref.watch(weeklyStatsProvider);
    final prs = ref.watch(personalRecordsProvider);

    final weightPoints = [
      for (final entry in measurements)
        if (entry.weightKg != null)
          ChartPoint(
            date: entry.date,
            value: units == Units.imperial
                ? UnitConverter.kgToLb(entry.weightKg!)
                : entry.weightKg!,
          ),
    ];

    // Oldest-first so the volume trend reads left to right.
    final volumePoints = [
      for (final log in logs.reversed)
        ChartPoint(
          date: log.startedAt,
          value: units == Units.imperial
              ? UnitConverter.kgToLb(log.totalVolumeKg)
              : log.totalVolumeKg,
        ),
    ];

    final totalVolume =
        logs.fold<double>(0, (sum, log) => sum + log.totalVolumeKg);

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
                      Text('Progress',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Your training trends at a glance.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.go(Routes.measurements),
                  icon: const Icon(Icons.straighten_rounded),
                  tooltip: 'Body measurements',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Workouts',
                    value: '${logs.length}',
                    icon: Icons.fitness_center_rounded,
                    sub: '${weekly.workouts} this week',
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
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Total volume',
                    value: UnitConverter.formatVolume(totalVolume, units),
                    icon: Icons.bar_chart_rounded,
                    accent: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: 'Time trained',
                    value: formatDurationText(
                        logs.fold<int>(0, (s, l) => s + l.durationSec)),
                    icon: Icons.timer_outlined,
                    accent: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Body weight'),
            LineChartCard(
              title: 'Weight trend',
              points: weightPoints,
              unitSuffix: ' ${UnitConverter.weightUnit(units)}',
              emptyMessage:
                  'Log your weight at least twice to see the trend.',
              trailing: TextButton(
                onPressed: () => context.go(Routes.measurements),
                child: const Text('Log'),
              ),
            ),
            const SectionHeader(title: 'Workout volume'),
            LineChartCard(
              title: 'Volume per workout',
              points: volumePoints,
              unitSuffix: ' ${UnitConverter.weightUnit(units)}',
              color: AppColors.secondary,
              emptyMessage:
                  'Complete two workouts to compare their total volume.',
            ),
            const SectionHeader(title: 'Activity'),
            BarChartCard(
              title: 'This week',
              subtitle: 'Workouts per day over the last 7 days',
              points: [
                for (final bucket in ref.watch(weeklyActivityProvider))
                  BarPoint(
                      label: bucket.label, value: bucket.count.toDouble()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            BarChartCard(
              title: 'Last 6 months',
              subtitle: 'Workouts per month',
              color: AppColors.secondary,
              points: [
                for (final bucket in ref.watch(monthlyActivityProvider))
                  BarPoint(
                      label: bucket.label, value: bucket.count.toDouble()),
              ],
            ),
            const SectionHeader(title: 'Personal records'),
            if (prs.isEmpty)
              GlassCard(
                child: EmptyState(
                  icon: Icons.emoji_events_rounded,
                  title: 'No records yet',
                  message:
                      'Log a bench press, squat, deadlift, overhead press, or '
                      'pull up and your PRs will appear here.',
                  compact: true,
                  actionLabel: 'Start a workout',
                  onAction: () => context.go(Routes.workouts),
                ),
              )
            else
              for (final entry in AppConstants.keyLifts.entries)
                if (prs[entry.key] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _PrCard(
                      liftName: entry.value,
                      records: prs[entry.key]!,
                      units: units,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({
    required this.liftName,
    required this.records,
    required this.units,
  });

  final String liftName;
  final Map<PrType, PrEntry> records;
  final Units units;

  String _value(PrEntry pr) => switch (pr.type) {
        PrType.highestWeight => UnitConverter.formatWeight(pr.value, units),
        PrType.highestVolume => UnitConverter.formatVolume(pr.value, units),
        PrType.mostReps => '${pr.value.toInt()}',
      };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(liftName,
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final type in PrType.values)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        records[type] == null
                            ? '—'
                            : _value(records[type]!),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (records[type] != null)
                        Text(
                          formatShortDate(
                              records[type]!.date, DateTime.now()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
