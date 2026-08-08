import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/exercise.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hive_exercise_repository.dart';
import '../domain/exercise_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
    (ref) => HiveExerciseRepository(ref.watch(exercisesBoxProvider)));

final exerciseListProvider = Provider<List<Exercise>>(
    (ref) => ref.watch(exerciseRepositoryProvider).getAll());

final exerciseByIdProvider = Provider.family<Exercise?, String>(
    (ref, id) => ref.watch(exerciseRepositoryProvider).byId(id));

class ExerciseSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final exerciseSearchQueryProvider =
    NotifierProvider<ExerciseSearchQuery, String>(ExerciseSearchQuery.new);

/// null = All groups.
class MuscleGroupFilter extends Notifier<MuscleGroup?> {
  @override
  MuscleGroup? build() => null;
  void set(MuscleGroup? value) => state = value;
}

final muscleGroupFilterProvider =
    NotifierProvider<MuscleGroupFilter, MuscleGroup?>(MuscleGroupFilter.new);

class FavoritesOnlyFilter extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final favoritesOnlyProvider =
    NotifierProvider<FavoritesOnlyFilter, bool>(FavoritesOnlyFilter.new);

/// Per-user favorite exercise IDs, persisted in the favorites box.
class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final userId =
        ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) return {};
    final json = ref.read(favoritesBoxProvider).get(userId);
    return ((json?['ids'] as List?)?.cast<String>() ?? []).toSet();
  }

  Future<void> toggle(String exerciseId) async {
    final next = {...state};
    if (!next.remove(exerciseId)) next.add(exerciseId);
    state = next;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId != null) {
      await ref
          .read(favoritesBoxProvider)
          .put(userId, {'ids': next.toList()});
    }
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

final filteredExercisesProvider = Provider<List<Exercise>>((ref) {
  final all = ref.watch(exerciseListProvider);
  final query = ref.watch(exerciseSearchQueryProvider).trim().toLowerCase();
  final group = ref.watch(muscleGroupFilterProvider);
  final favoritesOnly = ref.watch(favoritesOnlyProvider);
  final favorites = ref.watch(favoritesControllerProvider);

  return all.where((exercise) {
    if (group != null && exercise.muscleGroup != group) return false;
    if (favoritesOnly && !favorites.contains(exercise.id)) return false;
    if (query.isNotEmpty &&
        !exercise.name.toLowerCase().contains(query) &&
        !exercise.equipment.toLowerCase().contains(query) &&
        !exercise.targetMuscles
            .any((m) => m.toLowerCase().contains(query))) {
      return false;
    }
    return true;
  }).toList();
});
