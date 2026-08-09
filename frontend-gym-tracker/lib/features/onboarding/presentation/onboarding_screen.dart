import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/validators.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../auth/presentation/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _statsFormKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  int _step = 0;
  Gender? _gender;
  FitnessGoal? _goal;
  ExperienceLevel? _experience;
  int? _frequency;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  bool get _stepComplete => switch (_step) {
        0 => _gender != null,
        1 => _goal != null,
        2 => _experience != null,
        _ => _frequency != null,
      };

  void _next() {
    if (_step == 0) {
      if (_gender == null) {
        showErrorSnack(context, 'Select your gender to continue');
        return;
      }
      if (!_statsFormKey.currentState!.validate()) return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = UserProfile(
      gender: _gender!,
      age: int.parse(_age.text.trim()),
      heightCm: double.parse(_height.text.trim().replaceAll(',', '.')),
      weightKg: double.parse(_weight.text.trim().replaceAll(',', '.')),
      goal: _goal!,
      experience: _experience!,
      weeklyFrequency: _frequency!,
    );
    await ref.read(authControllerProvider.notifier).completeOnboarding(profile);
    // The router redirect moves to /home once the profile exists.
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(
        authControllerProvider.select((a) => a.user?.name ?? 'there'));
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (_step > 0)
                          IconButton(
                            onPressed: _back,
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(child: _ProgressDots(step: _step)),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatsStep(
                            formKey: _statsFormKey,
                            name: name,
                            gender: _gender,
                            onGender: (g) => setState(() => _gender = g),
                            age: _age,
                            height: _height,
                            weight: _weight,
                          ),
                          _ChoiceStep<FitnessGoal>(
                            title: "What's your goal?",
                            subtitle:
                                'We tailor your experience around this.',
                            options: FitnessGoal.values,
                            selected: _goal,
                            labelOf: (g) => g.label,
                            iconOf: _goalIcon,
                            subtitleOf: _goalSubtitle,
                            onSelect: (g) => setState(() => _goal = g),
                          ),
                          _ChoiceStep<ExperienceLevel>(
                            title: 'Your experience level?',
                            subtitle: 'Be honest — programs adapt to this.',
                            options: ExperienceLevel.values,
                            selected: _experience,
                            labelOf: (e) => e.label,
                            iconOf: _experienceIcon,
                            subtitleOf: _experienceSubtitle,
                            onSelect: (e) => setState(() => _experience = e),
                          ),
                          _ChoiceStep<int>(
                            title: 'How often will you train?',
                            subtitle: 'Days per week you can commit to.',
                            options: const [3, 4, 5, 6],
                            selected: _frequency,
                            labelOf: (d) => '$d days / week',
                            iconOf: (_) => Icons.calendar_month_rounded,
                            subtitleOf: _frequencySubtitle,
                            onSelect: (d) => setState(() => _frequency = d),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _step == _stepCount - 1 ? 'Finish' : 'Continue',
                      loading: _saving,
                      onPressed: _stepComplete || _step == 0 ? _next : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _goalIcon(FitnessGoal goal) => switch (goal) {
        FitnessGoal.buildMuscle => Icons.fitness_center_rounded,
        FitnessGoal.loseFat => Icons.local_fire_department_rounded,
        FitnessGoal.maintainWeight => Icons.balance_rounded,
        FitnessGoal.increaseStrength => Icons.bolt_rounded,
        FitnessGoal.improveEndurance => Icons.directions_run_rounded,
      };

  static String _goalSubtitle(FitnessGoal goal) => switch (goal) {
        FitnessGoal.buildMuscle => 'Add lean size with hypertrophy work',
        FitnessGoal.loseFat => 'Burn fat while keeping muscle',
        FitnessGoal.maintainWeight => 'Stay fit and hold your current shape',
        FitnessGoal.increaseStrength => 'Push your big lifts higher',
        FitnessGoal.improveEndurance => 'Build stamina and work capacity',
      };

  static IconData _experienceIcon(ExperienceLevel level) => switch (level) {
        ExperienceLevel.beginner => Icons.emoji_people_rounded,
        ExperienceLevel.intermediate => Icons.trending_up_rounded,
        ExperienceLevel.advanced => Icons.military_tech_rounded,
      };

  static String _experienceSubtitle(ExperienceLevel level) => switch (level) {
        ExperienceLevel.beginner => 'New to training, or under a year in',
        ExperienceLevel.intermediate => '1–3 years of consistent training',
        ExperienceLevel.advanced => '3+ years, confident with the big lifts',
      };

  static String _frequencySubtitle(int days) => switch (days) {
        3 => 'Great for full-body routines',
        4 => 'Ideal for upper / lower splits',
        5 => 'Push-pull-legs territory',
        _ => 'High-frequency training',
      };
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == step ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

class _StatsStep extends StatelessWidget {
  const _StatsStep({
    required this.formKey,
    required this.name,
    required this.gender,
    required this.onGender,
    required this.age,
    required this.height,
    required this.weight,
  });

  final GlobalKey<FormState> formKey;
  final String name;
  final Gender? gender;
  final ValueChanged<Gender> onGender;
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController weight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hey $name 👋',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('Tell us a bit about yourself.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xxl),
            Text('Gender', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final g in Gender.values)
                  SelectableChip(
                    label: g.label,
                    selected: gender == g,
                    onTap: () => onGender(g),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Age',
              controller: age,
              hint: 'e.g. 28',
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
                    controller: height,
                    hint: 'e.g. 178',
                    suffixText: 'cm',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: decimalInputFormatters,
                    validator: Validators.heightCm,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Weight',
                    controller: weight,
                    hint: 'e.g. 76.5',
                    suffixText: 'kg',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: decimalInputFormatters,
                    validator: Validators.weightKg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceStep<T> extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.subtitleOf,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final String Function(T) subtitleOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xxl),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: GlassCard(
                onTap: () => onSelect(option),
                borderColor:
                    option == selected ? scheme.primary : null,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(iconOf(option),
                          color: scheme.primary, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labelOf(option),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(subtitleOf(option),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: option == selected ? 1 : 0,
                      child: Icon(Icons.check_circle_rounded,
                          color: scheme.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
