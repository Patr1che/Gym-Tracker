import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/program.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/difficulty_badge.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../shell/presentation/app_shell.dart';
import 'program_providers.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programListProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(programListProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
              AppSpacing.xl, AppSpacing.screenH, kBottomNavClearance),
          children: [
            Text('Workouts',
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Pick a program or explore the exercise library.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              onTap: () => context.go(Routes.exerciseLibrary),
              gradient: LinearGradient(colors: [
                AppColors.secondary.withValues(alpha: 0.18),
                AppColors.secondary.withValues(alpha: 0.05),
              ]),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.secondaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exercise Library',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('50+ exercises with form tips',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            const SectionHeader(title: 'Training programs'),
            for (final program in programs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ProgramCard(program: program),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: () => context.go(Routes.programDetail(program.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(program.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              DifficultyBadge(difficulty: program.difficulty),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(program.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Meta(
                  icon: Icons.calendar_month_rounded,
                  label: '${program.daysPerWeek} days/week'),
              _Meta(
                  icon: Icons.schedule_rounded,
                  label: '~${program.estimatedDurationMin} min'),
              _Meta(
                  icon: Icons.fitness_center_rounded,
                  label:
                      '${program.days.fold<int>(0, (n, d) => n + d.exercises.length)} exercises'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text('View program →',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
