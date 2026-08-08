import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Gradient placeholder standing in for exercise images/GIFs in the MVP.
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar({
    super.key,
    required this.token,
    this.size = 56,
    this.radius = AppRadius.md,
  });

  /// Muscle-group token, e.g. 'chest'.
  final String token;
  final double size;
  final double radius;

  static IconData iconFor(String token) => switch (token) {
        'chest' => Icons.fitness_center_rounded,
        'back' => Icons.rowing_rounded,
        'shoulders' => Icons.sports_gymnastics_rounded,
        'arms' => Icons.sports_martial_arts_rounded,
        'legs' => Icons.directions_run_rounded,
        'core' => Icons.self_improvement_rounded,
        'cardio' => Icons.monitor_heart_rounded,
        _ => Icons.fitness_center_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.muscleGradient(token),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        iconFor(token),
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}
