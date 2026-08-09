import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/gradient_background.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The logo already carries the wordmark, so no separate app-name text.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Image.asset(
            'assets/logo.png',
            width: 148,
            height: 148,
            fit: BoxFit.cover,
            // Falls back to the mark if the asset is ever missing.
            errorBuilder: (context, error, stack) => Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 56, color: AppColors.bgDark),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared page chrome for auth screens: gradient backdrop, vertical
/// centering, and a 440px max width so forms stay narrow on web.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
