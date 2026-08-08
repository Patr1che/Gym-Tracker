import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum SnackType { success, error, info }

void showAppSnack(
  BuildContext context,
  String message, {
  SnackType type = SnackType.info,
}) {
  final (IconData icon, Color color) = switch (type) {
    SnackType.success => (Icons.check_circle_rounded, AppColors.success),
    SnackType.error => (Icons.error_rounded, AppColors.danger),
    SnackType.info => (Icons.info_rounded, AppColors.secondary),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
}

void showSuccessSnack(BuildContext context, String message) =>
    showAppSnack(context, message, type: SnackType.success);

void showErrorSnack(BuildContext context, String message) =>
    showAppSnack(context, message, type: SnackType.error);
