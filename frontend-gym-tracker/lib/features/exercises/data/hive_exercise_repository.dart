import '../../../core/models/exercise.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/exercise_repository.dart';

class HiveExerciseRepository implements ExerciseRepository {
  HiveExerciseRepository(this._box);

  final JsonBox _box;

  @override
  List<Exercise> getAll() {
    final list = _box.getAll().map(Exercise.fromJson).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Exercise? byId(String id) {
    final json = _box.get(id);
    return json == null ? null : Exercise.fromJson(json);
  }
}
