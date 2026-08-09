import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../shell/presentation/app_shell.dart';

/// Simple text page used by Privacy / Terms / About.
class InfoPageScreen extends StatelessWidget {
  const InfoPageScreen({
    super.key,
    required this.title,
    required this.sections,
    this.intro,
  });

  final String title;
  final String? intro;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          if (intro != null) ...[
            Text(intro!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final (heading, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(body,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScreen(
      title: 'Privacy',
      intro: 'GymTracker keeps your training data on your device.',
      sections: [
        (
          'What we store',
          'Your account details, workout logs, body measurements, favorites, '
              'and settings are saved in local storage on this device only.',
        ),
        (
          'What we send',
          'Nothing. This MVP has no backend, no analytics, and no third-party '
              'trackers. Your data never leaves the device.',
        ),
        (
          'Deleting your data',
          'Clearing the app\'s browser storage (or uninstalling the app) '
              'permanently removes everything, including your account.',
        ),
        (
          'Future cloud sync',
          'If optional cloud sync is added later, it will be off by default '
              'and require your explicit consent.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScreen(
      title: 'Terms',
      intro: 'Please read these terms before using GymTracker.',
      sections: [
        (
          'Not medical advice',
          'GymTracker is a training log, not a medical or fitness professional. '
              'Consult a qualified professional before starting a new program, '
              'especially if you have any health conditions or injuries.',
        ),
        (
          'Train safely',
          'Use appropriate weights and form. Estimated calories and suggested '
              'programs are general guidance, not personalized prescriptions.',
        ),
        (
          'Your data, your responsibility',
          'Because data is stored locally with no backup, clearing site data '
              'or losing the device means losing your history.',
        ),
        (
          'MVP software',
          'This is an early-stage app provided as is, without warranty of any '
              'kind.',
        ),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(Icons.fitness_center_rounded,
                      size: 36, color: AppColors.bgDark),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('GymTracker',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text('Version 1.0.0 (MVP)',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Feature(
                    icon: Icons.list_alt_rounded,
                    text: 'Built-in programs and a 50-exercise library'),
                _Feature(
                    icon: Icons.timer_outlined,
                    text: 'Guided sessions with an automatic rest timer'),
                _Feature(
                    icon: Icons.insights_rounded,
                    text: 'Progress charts, personal records, and measurements'),
                _Feature(
                    icon: Icons.cloud_off_rounded,
                    text: 'Fully offline — your data stays on your device',
                    isLast: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created by',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('Patriche Gerard Santos',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

