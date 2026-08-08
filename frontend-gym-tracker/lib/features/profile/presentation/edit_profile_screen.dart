import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/domain/validators.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late Gender _gender;
  late FitnessGoal _goal;
  late ExperienceLevel _experience;
  late int _frequency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    final profile = user?.profile;
    final units = ref.read(unitsProvider);

    _name = TextEditingController(text: user?.name ?? '');
    _age = TextEditingController(text: profile?.age.toString() ?? '');
    _height = TextEditingController(
      text: profile == null
          ? ''
          : units == Units.metric
              ? _trim(profile.heightCm)
              : _trim(UnitConverter.cmToIn(profile.heightCm)),
    );
    _weight = TextEditingController(
      text: profile == null
          ? ''
          : UnitConverter.formatWeight(profile.weightKg, units,
              withUnit: false),
    );
    _gender = profile?.gender ?? Gender.other;
    _goal = profile?.goal ?? FitnessGoal.buildMuscle;
    _experience = profile?.experience ?? ExperienceLevel.beginner;
    _frequency = profile?.weeklyFrequency ?? 3;
  }

  static String _trim(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final units = ref.read(unitsProvider);
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final heightCm = UnitConverter.parseLength(_height.text, units);
    final weightKg = UnitConverter.parseWeight(_weight.text, units);
    if (heightCm == null || weightKg == null) return;

    setState(() => _saving = true);
    await ref.read(authControllerProvider.notifier).updateUser(
          user.copyWith(
            name: _name.text.trim(),
            profile: UserProfile(
              gender: _gender,
              age: int.parse(_age.text.trim()),
              heightCm: heightCm,
              weightKg: weightKg,
              goal: _goal,
              experience: _experience,
              weeklyFrequency: _frequency,
            ),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showSuccessSnack(context, 'Profile updated');
    context.pop();
  }

  String? _validateHeight(String? value, Units units) {
    final cm = value == null ? null : UnitConverter.parseLength(value, units);
    if (value == null || value.trim().isEmpty) return 'Height is required';
    if (cm == null) return 'Enter a valid number';
    if (cm < 100 || cm > 250) {
      return units == Units.metric
          ? 'Height must be 100–250 cm'
          : 'Height must be 39–98 in';
    }
    return null;
  }

  String? _validateWeight(String? value, Units units) {
    final kg = value == null ? null : UnitConverter.parseWeight(value, units);
    if (value == null || value.trim().isEmpty) return 'Weight is required';
    if (kg == null) return 'Enter a valid number';
    if (kg < 30 || kg > 300) {
      return units == Units.metric
          ? 'Weight must be 30–300 kg'
          : 'Weight must be 66–661 lb';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final name = _name.text.trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
              AppSpacing.screenH, kBottomNavClearance),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppColors.bgDark),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Photo upload coming soon',
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Name',
              controller: _name,
              validator: Validators.name,
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Age',
              controller: _age,
              keyboardType: TextInputType.number,
              inputFormatters: intInputFormatters,
              validator: Validators.age,
              prefixIcon: Icons.cake_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Height',
                    controller: _height,
                    suffixText: UnitConverter.lengthUnit(units),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalInputFormatters,
                    validator: (v) => _validateHeight(v, units),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Weight',
                    controller: _weight,
                    suffixText: UnitConverter.weightUnit(units),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalInputFormatters,
                    validator: (v) => _validateWeight(v, units),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _ChipGroup<Gender>(
              label: 'Gender',
              options: Gender.values,
              selected: _gender,
              labelOf: (g) => g.label,
              onSelect: (g) => setState(() => _gender = g),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ChipGroup<FitnessGoal>(
              label: 'Goal',
              options: FitnessGoal.values,
              selected: _goal,
              labelOf: (g) => g.label,
              onSelect: (g) => setState(() => _goal = g),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ChipGroup<ExperienceLevel>(
              label: 'Experience',
              options: ExperienceLevel.values,
              selected: _experience,
              labelOf: (e) => e.label,
              onSelect: (e) => setState(() => _experience = e),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ChipGroup<int>(
              label: 'Workouts per week',
              options: const [3, 4, 5, 6],
              selected: _frequency,
              labelOf: (d) => '$d days',
              onSelect: (d) => setState(() => _frequency = d),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Save changes',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final String label;
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in options)
                SelectableChip(
                  label: labelOf(option),
                  selected: option == selected,
                  onTap: () => onSelect(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
