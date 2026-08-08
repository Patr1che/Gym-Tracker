import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Glassmorphism card. `blur: true` applies a real BackdropFilter — use it
/// ONLY on static surfaces (nav bar, headers, overlays); scrolling list items
/// must stay on the default faux glass for web performance.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.blur = false,
    this.onTap,
    this.onLongPress,
    this.gradient,
    this.borderColor,
    this.fillColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null
            ? (fillColor ?? scheme.surfaceContainerHighest)
            : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? scheme.outline),
      ),
      child: content,
    );

    if (blur) {
      card = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppBlur.glass, sigmaY: AppBlur.glass),
          child: card,
        ),
      );
    }
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}
