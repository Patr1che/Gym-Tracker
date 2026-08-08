import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/streak_calculator.dart';

void main() {
  final today = DateTime(2026, 8, 7); // a fixed 'today' for all cases

  int streak(List<DateTime> dates) =>
      StreakCalculator.currentStreak(workoutDates: dates, today: today);

  test('no workouts → 0', () {
    expect(streak([]), 0);
  });

  test('workout today only → 1', () {
    expect(streak([DateTime(2026, 8, 7, 18, 30)]), 1);
  });

  test('trained yesterday but not today → streak survives', () {
    expect(streak([DateTime(2026, 8, 6), DateTime(2026, 8, 5)]), 2);
  });

  test('last workout two days ago → streak broken', () {
    expect(streak([DateTime(2026, 8, 5), DateTime(2026, 8, 4)]), 0);
  });

  test('gap breaks the count', () {
    expect(
      streak([
        DateTime(2026, 8, 7),
        DateTime(2026, 8, 6),
        // gap on the 5th
        DateTime(2026, 8, 4),
      ]),
      2,
    );
  });

  test('long unbroken streak across a month boundary', () {
    final dates = [
      for (var i = 0; i < 10; i++) DateTime(2026, 8, 7 - i),
    ];
    expect(streak(dates), 10);
  });

  test('multiple workouts on the same day count once', () {
    expect(
      streak([
        DateTime(2026, 8, 7, 7),
        DateTime(2026, 8, 7, 19),
        DateTime(2026, 8, 6, 12),
      ]),
      2,
    );
  });
}
