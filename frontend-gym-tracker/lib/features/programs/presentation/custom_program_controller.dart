import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/program.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hive_custom_program_repository.dart';

final customProgramRepositoryProvider = Provider<HiveCustomProgramRepository>(
    (ref) => HiveCustomProgramRepository(ref.watch(customProgramsBoxProvider)));

/// The signed-in user's own programs, newest edits reflected immediately.
class CustomProgramsController extends Notifier<List<Program>> {
  @override
  List<Program> build() {
    final userId =
        ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (userId == null) return const [];
    return ref.read(customProgramRepositoryProvider).forUser(userId);
  }

  String? get _userId => ref.read(authControllerProvider).user?.id;

  /// An empty program with one day, ready to edit.
  Program blank() {
    final id = 'custom_${ref.read(uuidProvider)()}';
    return Program(
      id: id,
      name: '',
      description: '',
      difficulty: Difficulty.beginner,
      daysPerWeek: 1,
      estimatedDurationMin: 45,
      days: [
        ProgramDay(id: '${id}_d1', name: 'Day 1', exercises: const []),
      ],
    );
  }

  /// Copies a program (typically a seeded one) so it can be edited freely.
  /// New ids are generated so the copy never collides with the original.
  Program duplicateOf(Program source) {
    final id = 'custom_${ref.read(uuidProvider)()}';
    return Program(
      id: id,
      name: '${source.name} (my copy)',
      description: source.description,
      difficulty: source.difficulty,
      daysPerWeek: source.daysPerWeek,
      estimatedDurationMin: source.estimatedDurationMin,
      days: [
        for (var i = 0; i < source.days.length; i++)
          ProgramDay(
            id: '${id}_d${i + 1}',
            name: source.days[i].name,
            exercises: List.of(source.days[i].exercises),
          ),
      ],
    );
  }

  Future<void> save(Program program) async {
    final userId = _userId;
    if (userId == null) return;
    // daysPerWeek is derived, so it can never drift from the actual days.
    final normalized = Program(
      id: program.id,
      name: program.name.trim().isEmpty ? 'My Program' : program.name.trim(),
      description: program.description.trim(),
      difficulty: program.difficulty,
      daysPerWeek: program.days.length,
      estimatedDurationMin: program.estimatedDurationMin,
      days: program.days,
    );
    await ref.read(customProgramRepositoryProvider).save(userId, normalized);
    _reload();
  }

  Future<void> delete(String programId) async {
    final userId = _userId;
    if (userId == null) return;
    await ref.read(customProgramRepositoryProvider).delete(userId, programId);
    _reload();
  }

  void _reload() {
    final userId = _userId;
    state = userId == null
        ? const []
        : ref.read(customProgramRepositoryProvider).forUser(userId);
  }
}

final customProgramsProvider =
    NotifierProvider<CustomProgramsController, List<Program>>(
        CustomProgramsController.new);

final customProgramByIdProvider = Provider.family<Program?, String>((ref, id) {
  for (final program in ref.watch(customProgramsProvider)) {
    if (program.id == id) return program;
  }
  return null;
});

/// True when a program id belongs to the user rather than the seed data.
bool isCustomProgramId(String id) => id.startsWith('custom_');
