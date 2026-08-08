import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/program.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/difficulty_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';
import 'custom_program_controller.dart';
import 'program_providers.dart';

class ProgramDetailScreen extends ConsumerStatefulWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  ConsumerState<ProgramDetailScreen> createState() =>
      _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  int _dayIndex = 0;

  Future<void> _startDay(Program program, ProgramDay day) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    if (controller.hasActiveSession) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Replace active workout?',
        message: 'You already have a workout in progress. '
            'Starting a new one will discard it.',
        confirmLabel: 'Start new',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    final exercises = ref.read(exerciseRepositoryProvider);
    controller.start(program: program, day: day, resolve: exercises.byId);
    if (mounted) context.go(Routes.session);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = isCustomProgramId(widget.programId);
    final program = isCustom
        ? ref.watch(customProgramByIdProvider(widget.programId))
        : ref.watch(programByIdProvider(widget.programId));
    if (program == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Program not found',
        ),
      );
    }
    final day = program.days[_dayIndex.clamp(0, program.days.length - 1)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          if (isCustom) ...[
            IconButton(
              tooltip: 'Edit program',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(Routes.editProgram(program.id)),
            ),
            IconButton(
              tooltip: 'Delete program',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete ${program.name}?',
                  message: 'This program will be permanently removed. '
                      'Your logged workouts are kept.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!confirmed) return;
                await ref
                    .read(customProgramsProvider.notifier)
                    .delete(program.id);
                if (context.mounted) context.go(Routes.workouts);
              },
            ),
          ] else
            IconButton(
              tooltip: 'Copy and customize',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () => context.go(Routes.copyProgram(program.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.description,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DifficultyBadge(difficulty: program.difficulty),
                    Text(
                      '${program.daysPerWeek} days/week · '
                      '~${program.estimatedDurationMin} min per session',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: program.days.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => SelectableChip(
                label: program.days[index].name,
                selected: index == _dayIndex,
                onTap: () => setState(() => _dayIndex = index),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final exercise in day.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ProgramExerciseRow(exercise: exercise),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Start ${day.name}',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _startDay(program, day),
          ),
        ],
      ),
    );
  }
}

class _ProgramExerciseRow extends ConsumerWidget {
  const _ProgramExerciseRow({required this.exercise});

  final ProgramExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(exerciseByIdProvider(exercise.exerciseId));
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: resolved == null
          ? null
          : () => context.go(Routes.exerciseDetail(resolved.id)),
      child: Row(
        children: [
          ExerciseAvatar(
              token: resolved?.imagePlaceholder ?? 'chest', size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resolved?.name ?? exercise.exerciseId,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${exercise.sets} sets × ${exercise.repsText}'
                  ' · Rest ${exercise.restSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
