import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports the Override type from misc.dart, not the main library.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/network/network_providers.dart';
import 'package:gym_tracker/core/models/exercise.dart';
import 'package:gym_tracker/core/models/program.dart';
import 'package:gym_tracker/core/models/user.dart';
import 'package:gym_tracker/core/models/workout_log.dart';
import 'package:gym_tracker/core/theme/app_theme.dart';
import 'package:gym_tracker/features/auth/domain/auth_repository.dart';
import 'package:gym_tracker/features/exercises/domain/exercise_repository.dart';
import 'package:gym_tracker/features/measurements/domain/measurement_repository.dart';
import 'package:gym_tracker/core/models/measurement_entry.dart';
import 'package:gym_tracker/features/programs/domain/program_repository.dart';
import 'package:gym_tracker/features/settings/domain/settings_repository.dart';
import 'package:gym_tracker/core/models/user_settings.dart';
import 'package:gym_tracker/features/workout_session/domain/workout_log_repository.dart';

/// In-memory fakes so widget/controller tests never touch Hive.

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({List<User> users = const []}) {
    for (final user in users) {
      _users[user.id] = user;
    }
  }

  final Map<String, User> _users = {};
  var _nextId = 0;

  @override
  User? findById(String id) => _users[id];

  @override
  User? findByEmail(String email) {
    final needle = email.trim().toLowerCase();
    for (final user in _users.values) {
      if (user.email == needle) return user;
    }
    return null;
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (findByEmail(normalized) != null) {
      throw const AuthException('An account with this email already exists');
    }
    final user = User(
      id: 'user_${_nextId++}',
      name: name.trim(),
      email: normalized,
      passwordHash: 'hash:$password',
      salt: 'salt',
      createdAt: DateTime(2026, 1, 1),
      photoSeed: 0,
    );
    _users[user.id] = user;
    return user;
  }

  @override
  Future<User?> login({required String email, required String password}) async {
    final user = findByEmail(email);
    if (user == null || user.passwordHash != 'hash:$password') return null;
    return user;
  }

  @override
  Future<void> updateUser(User user) async => _users[user.id] = user;

  @override
  Future<bool> resetPassword({
    required String email,
    required String name,
    required String newPassword,
  }) async {
    final user = findByEmail(email);
    if (user == null ||
        user.name.trim().toLowerCase() != name.trim().toLowerCase()) {
      return false;
    }
    _users[user.id] = user.copyWith(passwordHash: 'hash:$newPassword');
    return true;
  }
}

class FakeExerciseRepository implements ExerciseRepository {
  FakeExerciseRepository(this.exercises);

  final List<Exercise> exercises;

  @override
  List<Exercise> getAll() => exercises;

  @override
  Exercise? byId(String id) {
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}

class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository(this.programs);

  final List<Program> programs;

  @override
  List<Program> getAll() => programs;

  @override
  Program? byId(String id) {
    for (final program in programs) {
      if (program.id == id) return program;
    }
    return null;
  }
}

class FakeWorkoutLogRepository implements WorkoutLogRepository {
  FakeWorkoutLogRepository([List<WorkoutLog> logs = const []]) {
    for (final log in logs) {
      saved[log.id] = log;
    }
  }

  final Map<String, WorkoutLog> saved = {};

  @override
  List<WorkoutLog> forUser(String userId) {
    final logs =
        saved.values.where((log) => log.userId == userId).toList();
    logs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return logs;
  }

  @override
  WorkoutLog? byId(String id) => saved[id];

  @override
  Future<void> save(WorkoutLog log) async => saved[log.id] = log;
}

class FakeMeasurementRepository implements MeasurementRepository {
  final Map<String, MeasurementEntry> saved = {};

  @override
  List<MeasurementEntry> forUser(String userId) {
    final entries =
        saved.values.where((e) => e.userId == userId).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Future<void> save(MeasurementEntry entry) async => saved[entry.id] = entry;

  @override
  Future<void> delete(String id) async => saved.remove(id);
}

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, UserSettings> saved = {};

  @override
  UserSettings load(String userId) => saved[userId] ?? const UserSettings();

  @override
  Future<void> save(String userId, UserSettings settings) async =>
      saved[userId] = settings;
}

// ---- fixtures ----

User testUser({String id = 'u1', bool onboarded = true}) => User(
      id: id,
      name: 'Alex Smith',
      email: 'alex@example.com',
      passwordHash: 'hash:secret123',
      salt: 'salt',
      createdAt: DateTime(2026, 1, 1),
      photoSeed: 1,
      profile: onboarded
          ? const UserProfile(
              gender: Gender.male,
              age: 28,
              heightCm: 178,
              weightKg: 80,
              goal: FitnessGoal.buildMuscle,
              experience: ExperienceLevel.intermediate,
              weeklyFrequency: 4,
            )
          : null,
    );

Exercise testExercise({
  required String id,
  required String name,
  MuscleGroup group = MuscleGroup.chest,
  String equipment = 'Barbell',
}) =>
    Exercise(
      id: id,
      name: name,
      muscleGroup: group,
      targetMuscles: const ['Pectoralis Major'],
      equipment: equipment,
      difficulty: Difficulty.intermediate,
      description: 'A test exercise.',
      tips: const ['Tip one', 'Tip two', 'Tip three'],
      commonMistakes: const ['Mistake one', 'Mistake two', 'Mistake three'],
      imagePlaceholder: group.name,
    );

Program testProgram({
  String id = 'prog_test',
  String name = 'Test Program',
  List<ProgramDay>? days,
}) =>
    Program(
      id: id,
      name: name,
      description: 'A test program.',
      difficulty: Difficulty.beginner,
      daysPerWeek: 3,
      estimatedDurationMin: 45,
      days: days ??
          const [
            ProgramDay(
              id: 'day1',
              name: 'Day 1',
              exercises: [
                ProgramExercise(
                    exerciseId: 'ex_bench_press',
                    sets: 2,
                    repsText: '8-12',
                    restSeconds: 60),
                ProgramExercise(
                    exerciseId: 'ex_squat',
                    sets: 2,
                    repsText: '6-10',
                    restSeconds: 90),
              ],
            ),
          ],
    );

/// Keeps a test on the local-only code path.
///
/// Without it, any test that builds the real repository providers gets the
/// server-backed implementations, which reach for [tokenStoreProvider] and the
/// network. These tests are about local behaviour, so sync is switched off.
final localOnly = syncEnabledProvider.overrideWithValue(false);

/// Pumps [child] inside a themed MaterialApp with the given provider overrides.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: child,
      ),
    ),
  );
}
