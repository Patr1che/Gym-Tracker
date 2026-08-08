import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/workout_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workoutLogsRevisionProvider);
    final log = ref.watch(workoutLogRepositoryProvider).byId(logId);
    final units = ref.watch(unitsProvider);

    if (log == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.history_rounded, title: 'Workout not found'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(log.dayName),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          Text(
            formatShortDate(log.startedAt, DateTime.now()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Duration',
                  value: formatDurationText(log.durationSec),
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Volume',
                  value: UnitConverter.formatVolume(log.totalVolumeKg, units),
                  icon: Icons.fitness_center_rounded,
                  accent: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Sets',
                  value: '${log.totalSets}',
                  icon: Icons.format_list_numbered_rounded,
                  accent: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Est. calories',
                  value: '${log.caloriesEst} kcal',
                  icon: Icons.local_fire_department_rounded,
                  accent: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Exercises', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final entry in log.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ExerciseBreakdown(entry: entry, units: units),
            ),
        ],
      ),
    );
  }
}

class _ExerciseBreakdown extends ConsumerWidget {
  const _ExerciseBreakdown({required this.entry, required this.units});

  final ExerciseLog entry;
  final Units units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(entry.exerciseId));
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseAvatar(
                  token: exercise?.imagePlaceholder ?? 'chest', size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(exercise?.name ?? entry.exerciseId,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < entry.sets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('Set ${i + 1}',
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                  Expanded(
                    child: Text(
                      entry.sets[i].skipped
                          ? 'Skipped'
                          : !entry.sets[i].completed
                              ? 'Not completed'
                              : '${UnitConverter.formatWeight(entry.sets[i].weightKg, units)}'
                                  '  ×  ${entry.sets[i].reps} reps',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: entry.sets[i].counts
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                  Icon(
                    entry.sets[i].skipped
                        ? Icons.remove_circle_outline_rounded
                        : entry.sets[i].completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: entry.sets[i].counts
                        ? AppColors.success
                        : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
