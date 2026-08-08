import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color foreground, Color? background, Gradient? gradient, Color? border) =
        switch (variant) {
      AppButtonVariant.primary => (
          isDark ? AppColors.bgDark : Colors.white,
          null,
          AppColors.primaryGradient,
          null,
        ),
      AppButtonVariant.secondary => (
          scheme.onSurface,
          scheme.surfaceContainerHighest,
          null,
          scheme.outline,
        ),
      AppButtonVariant.ghost => (scheme.primary, null, null, null),
      AppButtonVariant.danger => (
          AppColors.danger,
          AppColors.danger.withValues(alpha: 0.12),
          null,
          AppColors.danger.withValues(alpha: 0.4),
        ),
    };

    final radius = BorderRadius.circular(AppRadius.md);
    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || loading ? 1 : 0.5,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: background,
          gradient: variant == AppButtonVariant.primary ? gradient : null,
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border),
          boxShadow: variant == AppButtonVariant.primary && enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: foreground,
                ),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: foreground),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onPressed : null,
        child: child,
      ),
    );
  }
}
