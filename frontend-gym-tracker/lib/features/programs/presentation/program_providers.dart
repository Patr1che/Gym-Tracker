import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/program.dart';
import '../../../core/persistence/hive_boxes_provider.dart';
import '../data/hive_program_repository.dart';
import '../domain/program_repository.dart';

final programRepositoryProvider = Provider<ProgramRepository>(
    (ref) => HiveProgramRepository(ref.watch(programsBoxProvider)));

final programListProvider = Provider<List<Program>>(
    (ref) => ref.watch(programRepositoryProvider).getAll());

final programByIdProvider = Provider.family<Program?, String>(
    (ref, id) => ref.watch(programRepositoryProvider).byId(id));
