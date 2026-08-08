import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/unit_converter.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/measurement_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/line_chart_card.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../shell/presentation/app_shell.dart';
import 'log_measurement_sheet.dart';
import 'measurement_providers.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  MetricKind _metric = MetricKind.weight;

  String _format(MetricKind kind, double value, Units units) {
    if (kind.isWeight) return UnitConverter.formatWeight(value, units);
    if (kind.isPercent) return '${value.toStringAsFixed(1)}%';
    return UnitConverter.formatLength(value, units);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(measurementsControllerProvider);
    final units = ref.watch(unitsProvider);

    final points = [
      for (final entry in entries)
        if (_metric.read(entry) != null)
          ChartPoint(
            date: entry.date,
            value: _metric.isWeight && units == Units.imperial
                ? UnitConverter.kgToLb(_metric.read(entry)!)
                : !_metric.isWeight &&
                        !_metric.isPercent &&
                        units == Units.imperial
                    ? UnitConverter.cmToIn(_metric.read(entry)!)
                    : _metric.read(entry)!,
          ),
    ];

    final suffix = _metric.isWeight
        ? ' ${UnitConverter.weightUnit(units)}'
        : _metric.isPercent
            ? '%'
            : ' ${UnitConverter.lengthUnit(units)}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Body Measurements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await LogMeasurementSheet.show(context);
          if (saved && context.mounted) {
            showSuccessSnack(context, 'Measurements saved');
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log'),
      ),
      body: entries.isEmpty
          ? EmptyState(
              icon: Icons.straighten_rounded,
              title: 'No measurements yet',
              message:
                  'Log your weight and body measurements to watch them change over time.',
              actionLabel: 'Log measurements',
              onAction: () async {
                final saved = await LogMeasurementSheet.show(context);
                if (saved && context.mounted) {
                  showSuccessSnack(context, 'Measurements saved');
                }
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                  AppSpacing.screenH, kBottomNavClearance),
              children: [
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: MetricKind.values.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final kind = MetricKind.values[index];
                      return SelectableChip(
                        label: kind.label,
                        selected: kind == _metric,
                        onTap: () => setState(() => _metric = kind),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LineChartCard(
                  title: '${_metric.label} over time',
                  points: points,
                  unitSuffix: suffix,
                  color: AppColors.secondary,
                  emptyMessage:
                      'Log ${_metric.label.toLowerCase()} at least twice to see a trend.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Log history',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _EntryCard(
                      entry: entry,
                      units: units,
                      format: _format,
                      onDelete: () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Delete entry?',
                          message:
                              'This measurement entry will be permanently removed.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!confirmed) return;
                        await ref
                            .read(measurementsControllerProvider.notifier)
                            .remove(entry.id);
                        if (context.mounted) {
                          showSuccessSnack(context, 'Entry deleted');
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.units,
    required this.format,
    required this.onDelete,
  });

  final MeasurementEntry entry;
  final Units units;
  final String Function(MetricKind, double, Units) format;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final kind in MetricKind.values)
        if (kind.read(entry) != null)
          (kind.label, format(kind, kind.read(entry)!, units)),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatRelativeDate(entry.date, DateTime.now()),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete entry',
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (label, value) in values)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(value,
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
