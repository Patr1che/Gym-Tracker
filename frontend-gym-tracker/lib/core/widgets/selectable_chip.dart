import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pill chip for filters and onboarding choices. 44px tall (touch target).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? (isDark ? AppColors.bgDark : Colors.white)
        : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            // Transparent rather than absent: a Container insets its child by
            // the border width, so dropping the border on selection would
            // shrink the pill by 2px and shuffle the row.
            border: Border.all(
                color: selected ? Colors.transparent : scheme.outline),
          ),
          // A chip in a Wrap must shrink to the row it sits in, but the same
          // chip in a horizontal ListView gets unbounded width, where a flex
          // child would assert — so only claim flex when there is a width.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final text = Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (constraints.hasBoundedWidth) Flexible(child: text) else text,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
