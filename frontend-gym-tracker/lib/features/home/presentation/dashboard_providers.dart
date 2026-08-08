import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/program.dart';
import '../../programs/presentation/program_providers.dart';
import '../../progress/presentation/progress_providers.dart';

class SuggestedWorkout {
  const SuggestedWorkout({required this.program, required this.day});

  final Program program;
  final ProgramDay day;
}

/// The next workout to suggest: the day after the most recently completed one
/// in the same program, wrapping around. Falls back to the first day of the
/// first program for new users.
final suggestedWorkoutProvider = Provider<SuggestedWorkout?>((ref) {
  final programs = ref.watch(programListProvider);
  if (programs.isEmpty) return null;

  final lastLog = ref.watch(lastWorkoutProvider);
  if (lastLog?.programId == null) {
    final program = programs.first;
    return program.days.isEmpty
        ? null
        : SuggestedWorkout(program: program, day: program.days.first);
  }

  final program = programs.firstWhere(
    (p) => p.id == lastLog!.programId,
    orElse: () => programs.first,
  );
  if (program.days.isEmpty) return null;

  final lastIndex = program.days.indexWhere((d) => d.name == lastLog!.dayName);
  final nextIndex = lastIndex == -1 ? 0 : (lastIndex + 1) % program.days.length;
  return SuggestedWorkout(program: program, day: program.days[nextIndex]);
});
