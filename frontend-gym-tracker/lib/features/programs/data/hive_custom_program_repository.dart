import '../../../core/models/program.dart';
import '../../../core/persistence/json_box.dart';

/// User-created programs, stored per user alongside the read-only seeded ones.
///
/// Records are keyed `<userId>:<programId>` so one box serves every account
/// without a nested structure.
class HiveCustomProgramRepository {
  HiveCustomProgramRepository(this._box);

  final JsonBox _box;

  static String _key(String userId, String programId) => '$userId:$programId';

  List<Program> forUser(String userId) {
    final prefix = '$userId:';
    final programs = <Program>[];
    for (final key in _box.keys) {
      if (!key.startsWith(prefix)) continue;
      final json = _box.get(key);
      if (json != null) programs.add(Program.fromJson(json));
    }
    programs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return programs;
  }

  Program? byId(String userId, String programId) {
    final json = _box.get(_key(userId, programId));
    return json == null ? null : Program.fromJson(json);
  }

  Future<void> save(String userId, Program program) =>
      _box.put(_key(userId, program.id), program.toJson());

  Future<void> delete(String userId, String programId) =>
      _box.delete(_key(userId, programId));
}
