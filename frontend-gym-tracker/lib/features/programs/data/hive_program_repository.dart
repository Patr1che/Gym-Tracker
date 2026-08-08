import '../../../core/models/program.dart';
import '../../../core/persistence/json_box.dart';
import '../domain/program_repository.dart';

class HiveProgramRepository implements ProgramRepository {
  HiveProgramRepository(this._box);

  final JsonBox _box;

  @override
  List<Program> getAll() {
    final list = _box.getAll().map(Program.fromJson).toList();
    // Beginner programs first, then by name for stable ordering.
    list.sort((a, b) {
      final byDifficulty = a.difficulty.index.compareTo(b.difficulty.index);
      return byDifficulty != 0 ? byDifficulty : a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Program? byId(String id) {
    final json = _box.get(id);
    return json == null ? null : Program.fromJson(json);
  }
}
