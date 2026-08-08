import '../../../core/models/exercise.dart';

abstract interface class ExerciseRepository {
  List<Exercise> getAll();
  Exercise? byId(String id);
}
