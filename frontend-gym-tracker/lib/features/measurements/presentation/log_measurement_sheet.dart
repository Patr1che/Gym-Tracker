import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/domain/validators.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/measurement_entry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import 'measurement_providers.dart';

/// Bottom sheet for logging body measurements. Every field is optional except
/// that at least one value must be filled.
class LogMeasurementSheet extends ConsumerStatefulWidget {
  const LogMeasurementSheet({super.key, this.weightOnly = false});

  /// Quick-action variant used by the dashboard's "Log Weight".
  final bool weightOnly;

  static Future<bool> show(BuildContext context, {bool weightOnly = false}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogMeasurementSheet(weightOnly: weightOnly),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<LogMeasurementSheet> createState() =>
      _LogMeasurementSheetState();
}

class _LogMeasurementSheetState extends ConsumerState<LogMeasurementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <MetricKind, TextEditingController>{
    for (final kind in MetricKind.values) kind: TextEditingController(),
  };
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Prefill weight with the latest known value for quick adjustment.
    final current = ref.read(currentWeightKgProvider);
    if (current != null) {
      final units = ref.read(unitsProvider);
      _controllers[MetricKind.weight]!.text =
          UnitConverter.formatWeight(current, units, withUnit: false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<MetricKind> get _fields =>
      widget.weightOnly ? [MetricKind.weight] : MetricKind.values;

  double? _parse(MetricKind kind, Units units) {
    final text = _controllers[kind]!.text.trim();
    if (text.isEmpty) return null;
    if (kind.isWeight) return UnitConverter.parseWeight(text, units);
    if (kind.isPercent) return double.tryParse(text.replaceAll(',', '.'));
    return UnitConverter.parseLength(text, units);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final units = ref.read(unitsProvider);
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;

    final entry = MeasurementEntry(
      id: ref.read(uuidProvider)(),
      userId: userId,
      date: ref.read(clockProvider)(),
      weightKg: _parse(MetricKind.weight, units),
      bodyFatPct: _parse(MetricKind.bodyFat, units),
      chestCm: _parse(MetricKind.chest, units),
      waistCm: _parse(MetricKind.waist, units),
      armsCm: _parse(MetricKind.arms, units),
      legsCm: _parse(MetricKind.legs, units),
      shouldersCm: _parse(MetricKind.shoulders, units),
      neckCm: _parse(MetricKind.neck, units),
      hipsCm: _parse(MetricKind.hips, units),
    );

    if (entry.isEmpty) {
      showErrorSnack(context, 'Enter at least one measurement');
      return;
    }

    setState(() => _saving = true);
    await ref.read(measurementsControllerProvider.notifier).add(entry);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _validate(MetricKind kind, String? value, Units units) {
    if (value == null || value.trim().isEmpty) return null; // all optional
    if (kind.isPercent) return Validators.bodyFat(value);
    if (kind.isWeight) {
      final kg = UnitConverter.parseWeight(value, units);
      if (kg == null) return 'Enter a valid number';
      if (kg < 30 || kg > 300) {
        return 'Weight must be 30–300 kg (66–661 lb)';
      }
      return null;
    }
    final cm = UnitConverter.parseLength(value, units);
    if (cm == null) return 'Enter a valid number';
    if (cm < 10 || cm > 250) return 'Enter a realistic measurement';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.weightOnly ? 'Log weight' : 'Log measurements',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.weightOnly
                      ? 'Track your body weight over time.'
                      : 'Fill in what you measured — everything is optional.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final kind in _fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppTextField(
                      label: kind.label,
                      controller: _controllers[kind],
                      hint: 'Optional',
                      suffixText: kind.isWeight
                          ? UnitConverter.weightUnit(units)
                          : kind.isPercent
                              ? '%'
                              : UnitConverter.lengthUnit(units),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: decimalInputFormatters,
                      validator: (v) => _validate(kind, v, units),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Save',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
