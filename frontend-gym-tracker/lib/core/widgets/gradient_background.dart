import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dark gradient backdrop with soft brand-color glows. Wrap every screen's
/// body in this (screens keep their Scaffold transparent-ish surfaces).
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [AppColors.bgDark, AppColors.bgDarkAlt, AppColors.bgDark]
        : const [AppColors.bgLight, AppColors.bgLightAlt, AppColors.bgLight];
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: _Glow(
            size: 320,
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.20),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _Glow(
            size: 360,
            color: AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.16),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
