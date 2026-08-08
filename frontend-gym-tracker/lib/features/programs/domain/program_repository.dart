import '../../../core/models/program.dart';

abstract interface class ProgramRepository {
  List<Program> getAll();
  Program? byId(String id);
}
