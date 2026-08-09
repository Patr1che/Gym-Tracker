import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/difficulty_badge.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/exercise_avatar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../shell/presentation/app_shell.dart';
import '../exercise_providers.dart';
import '../widgets/exercise_video.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    this.standalone = false,
  });

  final String exerciseId;

  /// True when pushed on the root navigator (over a running workout) rather
  /// than inside the tab shell: the screen then paints its own backdrop and
  /// drops the padding reserved for the bottom nav bar.
  final bool standalone;

  Widget _backdrop(Widget scaffold) =>
      standalone ? GradientBackground(child: scaffold) : scaffold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    if (exercise == null) {
      return _backdrop(Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'Exercise not found',
          message: 'This exercise may have been removed.',
        ),
      ));
    }
    final favorite =
        ref.watch(favoritesControllerProvider).contains(exercise.id);

    return _backdrop(Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            onPressed: () => ref
                .read(favoritesControllerProvider.notifier)
                .toggle(exercise.id),
            tooltip: favorite ? 'Remove favorite' : 'Add favorite',
            icon: Icon(
              favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: favorite
                  ? AppColors.danger
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH,
            standalone ? AppSpacing.xxxl : kBottomNavClearance),
        children: [
          ExerciseVideo(exercise: exercise),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _InfoBadge(
                icon: ExerciseAvatar.iconFor(exercise.imagePlaceholder),
                label: exercise.muscleGroup.label,
              ),
              _InfoBadge(
                icon: Icons.handyman_outlined,
                label: exercise.equipment,
              ),
              DifficultyBadge(difficulty: exercise.difficulty),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to perform',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(exercise.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target muscles',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final muscle in exercise.targetMuscles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          muscle,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TipsCard(
            title: 'Form tips',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            items: exercise.tips,
          ),
          const SizedBox(height: AppSpacing.lg),
          _TipsCard(
            title: 'Common mistakes',
            icon: Icons.cancel_rounded,
            color: AppColors.danger,
            items: exercise.commonMistakes,
          ),
        ],
      ),
    ));
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(item,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
