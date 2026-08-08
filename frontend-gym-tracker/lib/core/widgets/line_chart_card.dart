import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'empty_state.dart';
import 'glass_card.dart';

class ChartPoint {
  const ChartPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

/// Time-series line chart. Guards against fl_chart's NaN/degenerate-range
/// crashes: fewer than 2 points renders an empty state instead.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.points,
    this.unitSuffix = '',
    this.color = AppColors.primary,
    this.emptyMessage = 'Log at least two entries to see a trend.',
    this.height = 200,
    this.trailing,
  });

  final String title;
  final List<ChartPoint> points;
  final String unitSuffix;
  final Color color;
  final String emptyMessage;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (sorted.length < 2)
            // Sized by its content — forcing the chart height would overflow
            // once the message wraps on a narrow screen.
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: height * 0.6),
              child: EmptyState(
                icon: Icons.show_chart_rounded,
                title: 'Not enough data',
                message: emptyMessage,
                compact: true,
              ),
            )
          else
            SizedBox(
              height: height,
              child: _buildChart(context, sorted, scheme),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(
      BuildContext context, List<ChartPoint> sorted, ColorScheme scheme) {
    final values = sorted.map((p) => p.value).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    // A flat series would collapse the axis to a zero range.
    if (maxY - minY < 0.5) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }

    final spots = [
      for (var i = 0; i < sorted.length; i++)
        FlSpot(i.toDouble(), sorted[i].value),
    ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (sorted.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(value.abs() >= 100 ? 0 : 1),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _labelInterval(sorted.length),
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= sorted.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(sorted[index].date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.surface,
            getTooltipItems: (touched) => touched.map((spot) {
              final point = sorted[spot.x.round()];
              return LineTooltipItem(
                '${_trim(point.value)}$unitSuffix\n'
                '${DateFormat('MMM d, y').format(point.date)}',
                Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: sorted.length <= 12,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeColor: scheme.surface,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _labelInterval(int count) =>
      count <= 6 ? 1 : (count / 5).ceilToDouble();

  static String _trim(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
  }
}
