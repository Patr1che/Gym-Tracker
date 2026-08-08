import 'enums.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.targetMuscles,
    required this.equipment,
    required this.difficulty,
    required this.description,
    required this.tips,
    required this.commonMistakes,
    required this.imagePlaceholder,
    this.videoId,
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final List<String> targetMuscles;
  final String equipment;
  final Difficulty difficulty;
  final String description;
  final List<String> tips;
  final List<String> commonMistakes;

  /// Visual token (muscle-group key) used to pick the placeholder gradient.
  final String imagePlaceholder;

  /// Optional YouTube video id (the 11-char code, not a full URL). When set,
  /// the detail screen embeds a player; otherwise it offers a YouTube search.
  final String? videoId;

  bool get hasVideo => videoId != null && videoId!.isNotEmpty;

  /// Search terms used when no [videoId] is curated for this exercise.
  String get videoSearchQuery => '$name proper form technique';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup.name,
        'targetMuscles': targetMuscles,
        'equipment': equipment,
        'difficulty': difficulty.name,
        'description': description,
        'tips': tips,
        'commonMistakes': commonMistakes,
        'imagePlaceholder': imagePlaceholder,
        'videoId': videoId,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        muscleGroup: MuscleGroup.fromName(json['muscleGroup'] as String?),
        targetMuscles: (json['targetMuscles'] as List?)?.cast<String>() ?? [],
        equipment: json['equipment'] as String? ?? '',
        difficulty: Difficulty.fromName(json['difficulty'] as String?),
        description: json['description'] as String? ?? '',
        tips: (json['tips'] as List?)?.cast<String>() ?? [],
        commonMistakes:
            (json['commonMistakes'] as List?)?.cast<String>() ?? [],
        imagePlaceholder: json['imagePlaceholder'] as String? ?? 'chest',
        videoId: json['videoId'] as String?,
      );
}
