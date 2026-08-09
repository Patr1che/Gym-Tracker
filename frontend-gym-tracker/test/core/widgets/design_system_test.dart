import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/widgets/app_button.dart';
import 'package:gym_tracker/core/widgets/difficulty_badge.dart';
import 'package:gym_tracker/core/widgets/empty_state.dart';
import 'package:gym_tracker/core/widgets/glass_card.dart';
import 'package:gym_tracker/core/widgets/line_chart_card.dart';
import 'package:gym_tracker/core/widgets/selectable_chip.dart';
import 'package:gym_tracker/core/widgets/stat_tile.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('GlassCard', () {
    testWidgets('renders its child and fires onTap', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: GlassCard(
            onTap: () => taps++,
            child: const Text('Card content'),
          ),
        ),
      );

      expect(find.text('Card content'), findsOneWidget);
      await tester.tap(find.text('Card content'));
      expect(taps, 1);
    });

    testWidgets('blur variant still renders its child', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: GlassCard(blur: true, child: Text('Blurred')),
        ),
      );
      expect(find.text('Blurred'), findsOneWidget);
    });
  });

  group('AppButton', () {
    testWidgets('shows a spinner and blocks taps while loading',
        (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: AppButton(
            label: 'Save',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(AppButton));
      expect(taps, 0);
    });

    testWidgets('a null callback disables the button', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: AppButton(label: 'Disabled')),
      );
      expect(find.text('Disabled'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      // Nothing to assert beyond not throwing — the tap is a no-op.
    });
  });

  testWidgets('StatTile renders its value and label', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: StatTile(
            label: 'Volume', value: '12.4k kg', icon: Icons.bar_chart_rounded),
      ),
    );
    expect(find.text('12.4k kg'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
  });

  testWidgets('SelectableChip reports taps', (tester) async {
    var tapped = false;
    await pumpApp(
      tester,
      Scaffold(
        body: SelectableChip(
          label: 'Chest',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('Chest'));
    expect(tapped, isTrue);
  });

  testWidgets('SelectableChip keeps its size when selected', (tester) async {
    // Selecting must not resize the pill: in a Wrap, a chip that grows or
    // shrinks on tap shifts every chip after it.
    await pumpApp(
      tester,
      Scaffold(
        body: Column(
          children: [
            SelectableChip(label: 'Beginner', selected: false, onTap: () {}),
            SelectableChip(label: 'Beginner', selected: true, onTap: () {}),
          ],
        ),
      ),
    );

    final chips = find.byType(SelectableChip);
    expect(tester.getSize(chips.at(0)), tester.getSize(chips.at(1)));
  });

  testWidgets('DifficultyBadge shows the level label', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: DifficultyBadge(difficulty: Difficulty.advanced),
      ),
    );
    expect(find.text('Advanced'), findsOneWidget);
  });

  testWidgets('EmptyState renders its action', (tester) async {
    var pressed = false;
    await pumpApp(
      tester,
      Scaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing here',
          message: 'Try again later.',
          actionLabel: 'Retry',
          onAction: () => pressed = true,
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(pressed, isTrue);
  });

  group('LineChartCard', () {
    testWidgets('falls back to an empty state below two points',
        (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: LineChartCard(
            title: 'Weight',
            points: [ChartPoint(date: DateTime(2026, 8, 1), value: 80)],
          ),
        ),
      );
      expect(find.text('Not enough data'), findsOneWidget);
    });

    testWidgets('renders a chart with enough points', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: LineChartCard(
            title: 'Weight',
            points: [
              ChartPoint(date: DateTime(2026, 8, 1), value: 80),
              ChartPoint(date: DateTime(2026, 8, 5), value: 79.4),
            ],
          ),
        ),
      );
      expect(find.text('Not enough data'), findsNothing);
      expect(find.text('Weight'), findsOneWidget);
    });

    testWidgets('a flat series does not collapse the axis', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: LineChartCard(
            title: 'Flat',
            points: [
              ChartPoint(date: DateTime(2026, 8, 1), value: 80),
              ChartPoint(date: DateTime(2026, 8, 2), value: 80),
              ChartPoint(date: DateTime(2026, 8, 3), value: 80),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
