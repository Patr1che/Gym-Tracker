import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/models/exercise.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('Exercise.hasVideo', () {
    test('false when no videoId is curated', () {
      expect(testExercise(id: 'ex_a', name: 'Bench Press').hasVideo, isFalse);
    });

    test('false for an empty videoId, so blanks fall back to search', () {
      final exercise = Exercise(
        id: 'ex_a',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        targetMuscles: const [],
        equipment: 'Barbell',
        difficulty: Difficulty.beginner,
        description: '',
        tips: const [],
        commonMistakes: const [],
        imagePlaceholder: 'chest',
        videoId: '',
      );
      expect(exercise.hasVideo, isFalse);
    });

    test('true when a videoId is present', () {
      final exercise = Exercise(
        id: 'ex_a',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        targetMuscles: const [],
        equipment: 'Barbell',
        difficulty: Difficulty.beginner,
        description: '',
        tips: const [],
        commonMistakes: const [],
        imagePlaceholder: 'chest',
        videoId: 'dQw4w9WgXcQ',
      );
      expect(exercise.hasVideo, isTrue);
    });
  });

  test('videoSearchQuery is built from the exercise name', () {
    final exercise = testExercise(id: 'ex_squat', name: 'Barbell Back Squat');
    expect(exercise.videoSearchQuery, 'Barbell Back Squat proper form technique');
  });

  group('videoId serialization', () {
    test('survives a JSON round trip', () {
      final exercise = Exercise(
        id: 'ex_a',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        targetMuscles: const ['Pectoralis Major'],
        equipment: 'Barbell',
        difficulty: Difficulty.intermediate,
        description: 'desc',
        tips: const ['t'],
        commonMistakes: const ['m'],
        imagePlaceholder: 'chest',
        videoId: 'abc12345678',
      );
      final restored = Exercise.fromJson(exercise.toJson());
      expect(restored.videoId, 'abc12345678');
      expect(restored.hasVideo, isTrue);
    });

    test('seed data without a videoId key parses to null, not a crash', () {
      // Every existing seeded exercise omits videoId — this must stay safe.
      final restored = Exercise.fromJson({
        'id': 'ex_bench_press',
        'name': 'Bench Press',
        'muscleGroup': 'chest',
        'targetMuscles': ['Pectoralis Major'],
        'equipment': 'Barbell',
        'difficulty': 'intermediate',
        'description': 'desc',
        'tips': ['t'],
        'commonMistakes': ['m'],
        'imagePlaceholder': 'chest',
      });
      expect(restored.videoId, isNull);
      expect(restored.hasVideo, isFalse);
    });
  });
}
