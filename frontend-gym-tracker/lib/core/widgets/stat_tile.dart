import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'glass_card.dart';

/// Compact glass tile: icon, big stat value, label. Used on the dashboard and
/// summary surfaces.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.sub,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTypography.stat(context, size: 24)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}
