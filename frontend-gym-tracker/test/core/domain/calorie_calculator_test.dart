import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/calorie_calculator.dart';

void main() {
  test('MET formula: 1 hour at MET 5 for 80 kg = 400 kcal', () {
    expect(
      CalorieCalculator.estimate(durationSec: 3600, weightKg: 80),
      400,
    );
  });

  test('scales with duration', () {
    expect(
      CalorieCalculator.estimate(durationSec: 1800, weightKg: 80),
      200,
    );
  });

  test('falls back to 70 kg when weight missing or invalid', () {
    expect(CalorieCalculator.estimate(durationSec: 3600), 350);
    expect(CalorieCalculator.estimate(durationSec: 3600, weightKg: 0), 350);
  });

  test('zero or negative duration yields zero', () {
    expect(CalorieCalculator.estimate(durationSec: 0, weightKg: 80), 0);
    expect(CalorieCalculator.estimate(durationSec: -5, weightKg: 80), 0);
  });
}
