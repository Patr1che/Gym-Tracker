import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/program.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/exercise_avatar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../exercises/presentation/exercise_providers.dart';
import '../../../shell/presentation/app_shell.dart';
import '../custom_program_controller.dart';
import '../program_providers.dart';
import '../widgets/exercise_picker_sheet.dart';

/// Creates or edits a user program.
///
/// Edits are held in local state and only persisted on Save, so backing out
/// leaves the stored program untouched.
class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId, this.copyFromId});

  /// Existing custom program to edit.
  final String? programId;

  /// Any program (usually seeded) to copy as a starting point.
  final String? copyFromId;

  @override
  ConsumerState<ProgramEditorScreen> createState() =>
      _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  late Program _draft;
  late final TextEditingController _name;
  late final TextEditingController _description;
  int _dayIndex = 0;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(customProgramsProvider.notifier);
    Program? source;
    if (widget.programId != null) {
      source = ref.read(customProgramByIdProvider(widget.programId!));
    } else if (widget.copyFromId != null) {
      final origin = ref.read(programByIdProvider(widget.copyFromId!)) ??
          ref.read(customProgramByIdProvider(widget.copyFromId!));
      if (origin != null) source = controller.duplicateOf(origin);
    }
    _draft = source ?? controller.blank();
    _name = TextEditingController(text: _draft.name);
    _description = TextEditingController(text: _draft.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isNew => widget.programId == null;

  void _update(Program next) => setState(() {
        _draft = next;
        _dirty = true;
      });

  Program _withDays(List<ProgramDay> days) => Program(
        id: _draft.id,
        name: _draft.name,
        description: _draft.description,
        difficulty: _draft.difficulty,
        daysPerWeek: days.length,
        estimatedDurationMin: _draft.estimatedDurationMin,
        days: days,
      );

  void _addDay() {
    final days = [
      ..._draft.days,
      ProgramDay(
        id: '${_draft.id}_d${_draft.days.length + 1}_${_draft.days.length}',
        name: 'Day ${_draft.days.length + 1}',
        exercises: const [],
      ),
    ];
    _update(_withDays(days));
    setState(() => _dayIndex = days.length - 1);
  }

  Future<void> _removeDay(int index) async {
    if (_draft.days.length == 1) {
      showErrorSnack(context, 'A program needs at least one day.');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${_draft.days[index].name}?',
      message: 'Its exercises will be removed from this program.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    final days = [..._draft.days]..removeAt(index);
    _update(_withDays(days));
    setState(() => _dayIndex = _dayIndex.clamp(0, days.length - 1));
  }

  Future<void> _renameDay(int index) async {
    final controller = TextEditingController(text: _draft.days[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename day'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final days = [..._draft.days];
    days[index] = ProgramDay(
        id: days[index].id,
        name: name.trim(),
        exercises: days[index].exercises);
    _update(_withDays(days));
  }

  Future<void> _addExercise() async {
    final exercise = await ExercisePickerSheet.show(context);
    if (exercise == null) return;
    final days = [..._draft.days];
    final day = days[_dayIndex];
    days[_dayIndex] = ProgramDay(
      id: day.id,
      name: day.name,
      exercises: [
        ...day.exercises,
        ProgramExercise(
            exerciseId: exercise.id,
            sets: 3,
            repsText: '8-12',
            restSeconds: 90),
      ],
    );
    _update(_withDays(days));
  }

  void _replaceExercise(int index, ProgramExercise next) {
    final days = [..._draft.days];
    final day = days[_dayIndex];
    final exercises = [...day.exercises];
    exercises[index] = next;
    days[_dayIndex] =
        ProgramDay(id: day.id, name: day.name, exercises: exercises);
    _update(_withDays(days));
  }

  void _removeExercise(int index) {
    final days = [..._draft.days];
    final day = days[_dayIndex];
    final exercises = [...day.exercises]..removeAt(index);
    days[_dayIndex] =
        ProgramDay(id: day.id, name: day.name, exercises: exercises);
    _update(_withDays(days));
  }

  void _reorderExercise(int oldIndex, int newIndex) {
    final days = [..._draft.days];
    final day = days[_dayIndex];
    final exercises = [...day.exercises];
    exercises.insert(newIndex, exercises.removeAt(oldIndex));
    days[_dayIndex] =
        ProgramDay(id: day.id, name: day.name, exercises: exercises);
    _update(_withDays(days));
  }

  Future<void> _save() async {
    final hasExercise = _draft.days.any((d) => d.exercises.isNotEmpty);
    if (!hasExercise) {
      showErrorSnack(context, 'Add at least one exercise before saving.');
      return;
    }
    final program = Program(
      id: _draft.id,
      name: _name.text,
      description: _description.text,
      difficulty: _draft.difficulty,
      daysPerWeek: _draft.days.length,
      estimatedDurationMin: _draft.estimatedDurationMin,
      days: _draft.days,
    );
    await ref.read(customProgramsProvider.notifier).save(program);
    if (!mounted) return;
    showSuccessSnack(context, _isNew ? 'Program created' : 'Program saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final day = _draft.days[_dayIndex.clamp(0, _draft.days.length - 1)];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showConfirmDialog(
          context,
          title: 'Discard changes?',
          message: 'Your edits to this program will not be saved.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isNew ? 'New program' : 'Edit program'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
              AppSpacing.screenH, kBottomNavClearance),
          children: [
            AppTextField(
              label: 'Program name',
              controller: _name,
              hint: 'e.g. My Push Pull Legs',
              onFieldSubmitted: (_) => setState(() => _dirty = true),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Description',
              controller: _description,
              hint: 'Optional',
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Difficulty',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final d in Difficulty.values)
                        SelectableChip(
                          label: d.label,
                          selected: _draft.difficulty == d,
                          onTap: () => _update(Program(
                            id: _draft.id,
                            name: _draft.name,
                            description: _draft.description,
                            difficulty: d,
                            daysPerWeek: _draft.daysPerWeek,
                            estimatedDurationMin: _draft.estimatedDurationMin,
                            days: _draft.days,
                          )),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text('Days',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                TextButton.icon(
                  onPressed: _addDay,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add day'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _draft.days.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => SelectableChip(
                  label: _draft.days[i].name,
                  selected: i == _dayIndex,
                  onTap: () => setState(() => _dayIndex = i),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _renameDay(_dayIndex),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Rename'),
                ),
                TextButton.icon(
                  onPressed: () => _removeDay(_dayIndex),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove day'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (day.exercises.isEmpty)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      Text('No exercises in ${day.name} yet',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Add exercises from the library.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: day.exercises.length,
                onReorderItem: _reorderExercise,
                itemBuilder: (context, i) => Padding(
                  key: ValueKey('${day.id}_$i'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _EditableExerciseRow(
                    index: i,
                    entry: day.exercises[i],
                    onChanged: (next) => _replaceExercise(i, next),
                    onRemove: () => _removeExercise(i),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Add exercise',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _addExercise,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Save program', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _EditableExerciseRow extends ConsumerWidget {
  const _EditableExerciseRow({
    required this.index,
    required this.entry,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ProgramExercise entry;
  final ValueChanged<ProgramExercise> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(entry.exerciseId));
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(Icons.drag_handle_rounded, size: 20),
                ),
              ),
              ExerciseAvatar(
                  token: exercise?.imagePlaceholder ?? 'chest', size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(exercise?.name ?? entry.exerciseId,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Remove exercise',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _NumberStepper(
                label: 'Sets',
                value: '${entry.sets}',
                onMinus: () => onChanged(_copy(sets: entry.sets - 1)),
                onPlus: () => onChanged(_copy(sets: entry.sets + 1)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RepsField(
                  value: entry.repsText,
                  onChanged: (v) => onChanged(_copy(repsText: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _NumberStepper(
                label: 'Rest',
                value: '${entry.restSeconds}s',
                onMinus: () =>
                    onChanged(_copy(restSeconds: entry.restSeconds - 15)),
                onPlus: () =>
                    onChanged(_copy(restSeconds: entry.restSeconds + 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ProgramExercise _copy({int? sets, String? repsText, int? restSeconds}) =>
      ProgramExercise(
        exerciseId: entry.exerciseId,
        sets: (sets ?? entry.sets).clamp(1, 10),
        repsText: repsText ?? entry.repsText,
        restSeconds: (restSeconds ?? entry.restSeconds).clamp(15, 300),
      );
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          children: [
            IconButton(
              onPressed: onMinus,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              visualDensity: VisualDensity.compact,
            ),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
            IconButton(
              onPressed: onPlus,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _RepsField extends StatefulWidget {
  const _RepsField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_RepsField> createState() => _RepsFieldState();
}

class _RepsFieldState extends State<_RepsField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reps', style: Theme.of(context).textTheme.labelSmall),
        TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          onChanged: widget.onChanged,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '8-12',
            contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          ),
        ),
      ],
    );
  }
}
