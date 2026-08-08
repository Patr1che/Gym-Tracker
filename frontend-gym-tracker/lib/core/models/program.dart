import 'enums.dart';

class ProgramExercise {
  const ProgramExercise({
    required this.exerciseId,
    required this.sets,
    required this.repsText,
    required this.restSeconds,
  });

  final String exerciseId;
  final int sets;

  /// Display target, e.g. '8-12' or '30-60 sec'.
  final String repsText;
  final int restSeconds;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'repsText': repsText,
        'restSeconds': restSeconds,
      };

  factory ProgramExercise.fromJson(Map<String, dynamic> json) =>
      ProgramExercise(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        repsText: json['repsText'] as String? ?? '8-12',
        restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      );
}

class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<ProgramExercise> exercises;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        exercises: (json['exercises'] as List? ?? [])
            .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Program {
  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.daysPerWeek,
    required this.estimatedDurationMin,
    required this.days,
  });

  final String id;
  final String name;
  final String description;
  final Difficulty difficulty;
  final int daysPerWeek;
  final int estimatedDurationMin;
  final List<ProgramDay> days;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'difficulty': difficulty.name,
        'daysPerWeek': daysPerWeek,
        'estimatedDurationMin': estimatedDurationMin,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        difficulty: Difficulty.fromName(json['difficulty'] as String?),
        daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 3,
        estimatedDurationMin:
            (json['estimatedDurationMin'] as num?)?.toInt() ?? 60,
        days: (json['days'] as List? ?? [])
            .map((d) => ProgramDay.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
