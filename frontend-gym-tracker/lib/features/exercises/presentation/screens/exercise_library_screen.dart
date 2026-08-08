import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/exercise.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/difficulty_badge.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/exercise_avatar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../shell/presentation/app_shell.dart';
import '../exercise_providers.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
        text: ref.read(exerciseSearchQueryProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    ref.read(exerciseSearchQueryProvider.notifier).set('');
    ref.read(muscleGroupFilterProvider.notifier).set(null);
    if (ref.read(favoritesOnlyProvider)) {
      ref.read(favoritesOnlyProvider.notifier).toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(filteredExercisesProvider);
    final group = ref.watch(muscleGroupFilterProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final favorites = ref.watch(favoritesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Exercise Library')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(exerciseListProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (value) => ref
                          .read(exerciseSearchQueryProvider.notifier)
                          .set(value),
                      decoration: InputDecoration(
                        hintText: 'Search exercises, muscles, equipment…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  ref
                                      .read(
                                          exerciseSearchQueryProvider.notifier)
                                      .set('');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SelectableChip(
                            label: 'Favorites',
                            icon: Icons.favorite_rounded,
                            selected: favoritesOnly,
                            onTap: () => ref
                                .read(favoritesOnlyProvider.notifier)
                                .toggle(),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SelectableChip(
                            label: 'All',
                            selected: group == null,
                            onTap: () => ref
                                .read(muscleGroupFilterProvider.notifier)
                                .set(null),
                          ),
                          for (final g in MuscleGroup.values) ...[
                            const SizedBox(width: AppSpacing.sm),
                            SelectableChip(
                              label: g.label,
                              selected: group == g,
                              onTap: () => ref
                                  .read(muscleGroupFilterProvider.notifier)
                                  .set(g),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            if (exercises.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No exercises found',
                  message: favoritesOnly
                      ? 'You have no favorites matching these filters yet. '
                          'Tap the heart on any exercise to save it.'
                      : 'Try a different search or filter.',
                  actionLabel: 'Clear filters',
                  onAction: _clearFilters,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                    AppSpacing.screenH, kBottomNavClearance),
                sliver: SliverList.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _ExerciseCard(
                    exercise: exercises[index],
                    favorite: favorites.contains(exercises[index].id),
                    onFavorite: () => ref
                        .read(favoritesControllerProvider.notifier)
                        .toggle(exercises[index].id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.favorite,
    required this.onFavorite,
  });

  final Exercise exercise;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go(Routes.exerciseDetail(exercise.id)),
      child: Row(
        children: [
          ExerciseAvatar(token: exercise.imagePlaceholder),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${exercise.muscleGroup.label} · ${exercise.equipment}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                DifficultyBadge(difficulty: exercise.difficulty),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavorite,
            tooltip: favorite ? 'Remove favorite' : 'Add favorite',
            icon: Icon(
              favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: favorite
                  ? AppColors.danger
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
