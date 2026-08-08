import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/exercise.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/exercise_avatar.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../exercises/presentation/exercise_providers.dart';

/// Searchable exercise list. Returns the chosen [Exercise], or null.
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key});

  static Future<Exercise?> show(BuildContext context) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: ExercisePickerSheet(),
      ),
    );
  }

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final _search = TextEditingController();
  MuscleGroup? _group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final all = ref.watch(exerciseListProvider);
    final results = all.where((e) {
      if (_group != null && e.muscleGroup != _group) return false;
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.equipment.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add exercise',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SelectableChip(
                    label: 'All',
                    selected: _group == null,
                    onTap: () => setState(() => _group = null),
                  ),
                  for (final g in MuscleGroup.values) ...[
                    const SizedBox(width: AppSpacing.sm),
                    SelectableChip(
                      label: g.label,
                      selected: _group == g,
                      onTap: () => setState(() => _group = g),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No exercises found',
                      message: 'Try a different search or filter.',
                      compact: true,
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final exercise = results[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ExerciseAvatar(
                              token: exercise.imagePlaceholder, size: 44),
                          title: Text(exercise.name),
                          subtitle: Text(
                              '${exercise.muscleGroup.label} · ${exercise.equipment}'),
                          onTap: () =>
                              Navigator.of(context).pop(exercise),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
