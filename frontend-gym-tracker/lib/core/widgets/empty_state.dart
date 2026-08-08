import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact variant for inline card slots (no vertical centering).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 80,
          height: compact ? 56 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.10),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: compact ? 26 : 36, color: scheme.primary),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
        Text(title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            expand: false,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(child: content),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: content,
      ),
    );
  }
}
