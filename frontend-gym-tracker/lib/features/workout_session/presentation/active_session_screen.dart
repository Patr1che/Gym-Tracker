import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/domain/pr_detector.dart';
import '../../../core/domain/unit_converter.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/workout_log.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/circular_timer.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/active_session.dart';
import 'session_controller.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  bool _finishing = false;

  Future<void> _finish(ActiveSessionState session) async {
    if (!session.allDone) {
      final remaining = session.totalSets - session.completedSets;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Finish workout?',
        message:
            'You still have $remaining ${remaining == 1 ? 'set' : 'sets'} left. '
            'Unfinished sets won\'t count toward your stats.',
        confirmLabel: 'Finish',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _finishing = true);
    final summary =
        await ref.read(sessionControllerProvider.notifier).finish();
    if (!mounted || summary == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _SummarySheet(summary: summary),
    );
    if (mounted) context.go(Routes.history);
  }

  Future<void> _abandon() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Abandon workout?',
      message: 'This workout will be discarded and nothing will be saved.',
      confirmLabel: 'Abandon',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(sessionControllerProvider.notifier).abandon();
    if (mounted) context.go(Routes.home);
  }

  void _minimize() {
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

    if (session == null) {
      if (!_finishing) {
        // No active workout (e.g. deep link) — bounce home.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(Routes.home);
        });
      }
      return const Scaffold(body: GradientBackground(child: SizedBox()));
    }

    final resting = session.resting;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                session: session,
                onMinimize: _minimize,
                onAbandon: _abandon,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenH),
                      children: [
                        _ExercisePager(session: session),
                        const SizedBox(height: AppSpacing.md),
                        _CurrentExerciseCard(session: session),
                        const SizedBox(height: AppSpacing.md),
                        _SetList(session: session),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
              if (resting)
                _RestPanel(session: session)
              else
                _Controls(session: session, onFinish: () => _finish(session)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.onMinimize,
    required this.onAbandon,
  });

  final ActiveSessionState session;
  final VoidCallback onMinimize;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final progress =
        session.totalSets == 0 ? 0.0 : session.completedSets / session.totalSets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onMinimize,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                tooltip: 'Minimize — workout keeps running',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(session.dayName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    Text(session.programName,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                onPressed: onAbandon,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Abandon workout',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _ElapsedClock(startedAt: session.startedAt),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                        value: progress, minHeight: 6),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${session.completedSets}/${session.totalSets} sets',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live elapsed-time chip; wall-clock derived so throttled ticks stay honest.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        DateTime.now().difference(widget.startedAt).inSeconds;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(formatClock(elapsed),
            style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Horizontal strip of exercise avatars — tap to jump.
class _ExercisePager extends ConsumerWidget {
  const _ExercisePager({required this.session});

  final ActiveSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: session.exercises.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final exercise = session.exercises[index];
          final selected = index == session.currentIndex;
          return GestureDetector(
            onTap: () => ref
                .read(sessionControllerProvider.notifier)
                .goToExercise(index),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md + 3),
                    border: Border.all(
                      color: selected ? scheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Opacity(
                    opacity: exercise.isDone && !selected ? 0.45 : 1,
                    child:
                        ExerciseAvatar(token: exercise.muscleToken, size: 52),
                  ),
                ),
                if (exercise.isDone)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.check_rounded,
                          size: 10, color: Colors.black),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurrentExerciseCard extends ConsumerWidget {
  const _CurrentExerciseCard({required this.session});

  final ActiveSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = session.current;
    final setNumber = exercise.isDone
        ? exercise.sets.length
        : exercise.nextSetIndex + 1;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      // push, not go: the session stays underneath, so back returns to it.
      onTap: () => context.push(Routes.sessionExercise(exercise.exerciseId)),
      child: Row(
        children: [
          ExerciseAvatar(token: exercise.muscleToken, size: 64),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise ${session.currentIndex + 1} of '
                  '${session.exercises.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(exercise.exerciseName,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  exercise.isDone
                      ? 'All sets done'
                      : 'Set $setNumber of ${exercise.sets.length}'
                          ' · Target ${exercise.repsText} reps'
                          ' · Rest ${exercise.restSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Explicit affordance — the whole card opens it, but the workout
          // screen gives no other hint that the guide exists.
          Semantics(
            button: true,
            label: 'How to perform ${exercise.exerciseName}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    size: 26, color: scheme.primary),
                const SizedBox(height: 2),
                Text('How to',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetList extends ConsumerWidget {
  const _SetList({required this.session});

  final ActiveSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final exercise = session.current;
    final currentSet = exercise.nextSetIndex;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < exercise.sets.length; i++)
            if (i == currentSet)
              _CurrentSetEditor(
                key: ValueKey('editor-${session.currentIndex}-$i'),
                setIndex: i,
                set: exercise.sets[i],
                units: units,
              )
            else
              _SetRow(
                index: i,
                set: exercise.sets[i],
                units: units,
                isUpcoming: currentSet != -1 && i > currentSet,
              ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.units,
    required this.isUpcoming,
  });

  final int index;
  final SetLog set;
  final Units units;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = set.skipped
        ? (Icons.remove_circle_outline_rounded, scheme.onSurfaceVariant)
        : set.completed
            ? (Icons.check_circle_rounded, AppColors.success)
            : (Icons.radio_button_unchecked_rounded, scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _SetNumber(index: index, dimmed: isUpcoming || set.skipped),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              set.skipped
                  ? 'Skipped'
                  : '${UnitConverter.formatWeight(set.weightKg, units)}'
                      '  ×  ${set.reps} reps',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUpcoming
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                        : scheme.onSurface,
                  ),
            ),
          ),
          Icon(icon, size: 20, color: color),
        ],
      ),
    );
  }
}

class _SetNumber extends StatelessWidget {
  const _SetNumber({required this.index, this.dimmed = false, this.active = false});

  final int index;
  final bool dimmed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? scheme.primary
            : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${index + 1}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active
                  ? AppColors.bgDark
                  : dimmed
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                      : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Editable weight/reps for the set about to be performed. Keyed by
/// (exercise, set) so controllers re-seed when the target set changes.
class _CurrentSetEditor extends ConsumerStatefulWidget {
  const _CurrentSetEditor({
    super.key,
    required this.setIndex,
    required this.set,
    required this.units,
  });

  final int setIndex;
  final SetLog set;
  final Units units;

  @override
  ConsumerState<_CurrentSetEditor> createState() => _CurrentSetEditorState();
}

class _CurrentSetEditorState extends ConsumerState<_CurrentSetEditor> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: widget.set.weightKg == 0
          ? ''
          : UnitConverter.formatWeight(widget.set.weightKg, widget.units,
              withUnit: false),
    );
    _reps = TextEditingController(text: widget.set.reps.toString());
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _pushWeight() {
    final kg = UnitConverter.parseWeight(_weight.text, widget.units) ?? 0;
    ref
        .read(sessionControllerProvider.notifier)
        .updateCurrentSet(weightKg: kg < 0 ? 0 : kg);
  }

  void _pushReps() {
    final reps = int.tryParse(_reps.text) ?? 0;
    ref
        .read(sessionControllerProvider.notifier)
        .updateCurrentSet(reps: reps < 0 ? 0 : reps);
  }

  void _bumpWeight(double deltaDisplayUnits) {
    final current =
        UnitConverter.parseWeight(_weight.text, widget.units) ?? 0;
    final deltaKg = widget.units == Units.metric
        ? deltaDisplayUnits
        : UnitConverter.lbToKg(deltaDisplayUnits);
    final next = (current + deltaKg).clamp(0, 999).toDouble();
    _weight.text =
        UnitConverter.formatWeight(next, widget.units, withUnit: false);
    _pushWeight();
  }

  void _bumpReps(int delta) {
    final next = ((int.tryParse(_reps.text) ?? 0) + delta).clamp(0, 200);
    _reps.text = next.toString();
    _pushReps();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.primary, width: 1.5),
        color: scheme.primary.withValues(alpha: 0.06),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SetNumber(index: widget.setIndex, active: true),
              const SizedBox(width: AppSpacing.md),
              Text('Current set',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final weight = _StepperField(
                label: 'Weight (${UnitConverter.weightUnit(widget.units)})',
                controller: _weight,
                onMinus: () => _bumpWeight(-2.5),
                onPlus: () => _bumpWeight(2.5),
                onChanged: (_) => _pushWeight(),
                hint: '0',
              );
              final reps = _StepperField(
                label: 'Reps',
                controller: _reps,
                onMinus: () => _bumpReps(-1),
                onPlus: () => _bumpReps(1),
                onChanged: (_) => _pushReps(),
                hint: '10',
              );
              // Each stepper spends 88px on its two round buttons, so side by
              // side on a narrow phone leaves the input too cramped to show
              // even two digits. Below that, one per row.
              if (constraints.maxWidth < _StepperField.sideBySideMinWidth) {
                return Column(
                  children: [
                    weight,
                    const SizedBox(height: AppSpacing.md),
                    reps,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: weight),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: reps),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
    required this.hint,
  });

  /// Two steppers fit on one line only above this width. Measured: a 360dp
  /// phone gives this row 269px, so each stepper gets 128 — 72px of round
  /// buttons and ~48px of digits, which covers three digits and a decimal.
  /// A 320dp phone gives 229px, too little, so there they stack instead.
  static const double sideBySideMinWidth = 260;

  final String label;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _RoundIconButton(icon: Icons.remove_rounded, onTap: onMinus),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.stat(context, size: 20),
                  decoration: InputDecoration(
                    hintText: hint,
                    // Horizontal padding here is width the digits can't use.
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.md),
                  ),
                ),
              ),
            ),
            _RoundIconButton(icon: Icons.add_rounded, onTap: onPlus),
          ],
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          // 36, not 44: the two buttons are pure width tax on the number
          // beside them, and at 44 a phone this size clipped two digits.
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Below this row width, Prev/Next go icon-only and the primary button drops
/// its tick — measured against "Complete Set" at `labelLarge`.
const double _tightControlsWidth = 300;

class _Controls extends ConsumerWidget {
  const _Controls({required this.session, required this.onFinish});

  final ActiveSessionState session;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider.notifier);
    final exercise = session.current;
    final isFirst = session.currentIndex == 0;
    final isLast = session.currentIndex == session.exercises.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
          AppSpacing.screenH, AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Prev/Next flank the primary action, so every pixel they
                  // take comes out of its label. On a narrow phone shrink
                  // them and drop the tick, or "Complete Set" ellipsises.
                  final tight = constraints.maxWidth < _tightControlsWidth;
                  return Row(
                    children: [
                      _EdgeButton(
                        icon: Icons.skip_previous_rounded,
                        label: 'Prev',
                        enabled: !isFirst,
                        compact: tight,
                        onTap: controller.previousExercise,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: exercise.isDone
                            ? AppButton(
                                label: session.allDone
                                    ? 'All sets done 🎉'
                                    : 'Next exercise',
                                variant: AppButtonVariant.secondary,
                                onPressed: session.allDone
                                    ? null
                                    : controller.nextExercise,
                              )
                            : AppButton(
                                label: 'Complete Set',
                                icon: tight ? null : Icons.check_rounded,
                                onPressed: controller.completeSet,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _EdgeButton(
                        icon: Icons.skip_next_rounded,
                        label: 'Next',
                        enabled: !isLast,
                        compact: tight,
                        onTap: controller.nextExercise,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: exercise.isDone ? null : controller.skipSet,
                      icon: const Icon(Icons.redo_rounded, size: 18),
                      label: const Text('Skip set'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onFinish,
                      icon: const Icon(Icons.flag_rounded, size: 18),
                      label: const Text('Finish Workout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeButton extends StatelessWidget {
  const _EdgeButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// Icon only, at the minimum touch width — for phones too narrow to spare
  /// the room. The skip glyphs carry the meaning; the word is a nicety.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: compact ? 44 : 56,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: scheme.onSurface),
                if (!compact)
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestPanel extends ConsumerWidget {
  const _RestPanel({required this.session});

  final ActiveSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider.notifier);
    final remaining = controller.restRemainingSeconds;
    final total =
        session.restTotalSeconds == 0 ? 1 : session.restTotalSeconds;

    return GlassCard(
      blur: true,
      margin: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
          AppSpacing.screenH, AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          CircularTimer(
            progress: remaining / total,
            size: 88,
            strokeWidth: 8,
            child: Text(formatClock(remaining),
                style: AppTypography.stat(context, size: 20)),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest up 💨',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Next: ${session.current.exerciseName}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '+30s',
                        variant: AppButtonVariant.secondary,
                        height: 44,
                        onPressed: () => controller.extendRest(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Skip',
                        height: 44,
                        onPressed: controller.skipRest,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySheet extends ConsumerWidget {
  const _SummarySheet({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final log = summary.log;
    return SafeArea(
      // Scrollable: on a short screen the stats, PR list and button together
      // are taller than the sheet can be.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Workout complete! 🎉',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${log.dayName} · ${log.completedExerciseCount} exercises',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Duration',
                      value: formatDurationText(log.durationSec),
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: 'Volume',
                      value: UnitConverter.formatVolume(log.totalVolumeKg, units),
                      icon: Icons.fitness_center_rounded,
                      accent: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Sets',
                      value: '${log.totalSets}',
                      icon: Icons.format_list_numbered_rounded,
                      accent: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: 'Est. calories',
                      value: '${log.caloriesEst} kcal',
                      icon: Icons.local_fire_department_rounded,
                      accent: AppColors.danger,
                    ),
                  ),
                ],
              ),
              if (summary.newPrs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.16),
                    AppColors.secondary.withValues(alpha: 0.12),
                  ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏆 New personal records',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      for (final pr in summary.newPrs)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  '${AppConstants.keyLifts[pr.exerciseId] ?? pr.exerciseId}'
                                  ' — ${pr.type.label}: ${_prValue(pr, units)}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _prValue(PrEntry pr, Units units) => switch (pr.type) {
        PrType.highestWeight => UnitConverter.formatWeight(pr.value, units),
        PrType.highestVolume => UnitConverter.formatVolume(pr.value, units),
        PrType.mostReps => '${pr.value.toInt()} reps',
      };
}
