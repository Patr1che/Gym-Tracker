import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/unit_converter.dart';
import 'package:gym_tracker/core/models/enums.dart';

void main() {
  group('weight conversion', () {
    test('kg to lb and back is stable', () {
      expect(UnitConverter.kgToLb(100), closeTo(220.46, 0.01));
      expect(UnitConverter.lbToKg(UnitConverter.kgToLb(82.5)),
          closeTo(82.5, 0.0001));
    });

    test('formatWeight respects units and trims decimals', () {
      expect(UnitConverter.formatWeight(100, Units.metric), '100 kg');
      expect(UnitConverter.formatWeight(82.5, Units.metric), '82.5 kg');
      expect(UnitConverter.formatWeight(100, Units.imperial), '220.5 lb');
    });

    test('parseWeight converts imperial input to kg', () {
      expect(UnitConverter.parseWeight('100', Units.metric), 100);
      expect(UnitConverter.parseWeight('220.46', Units.imperial),
          closeTo(100, 0.01));
      expect(UnitConverter.parseWeight('76,5', Units.metric), 76.5);
      expect(UnitConverter.parseWeight('junk', Units.metric), isNull);
    });
  });

  group('length conversion', () {
    test('cm/inch round trip', () {
      expect(UnitConverter.cmToIn(2.54), closeTo(1, 0.0001));
      expect(UnitConverter.inToCm(UnitConverter.cmToIn(92)),
          closeTo(92, 0.0001));
    });

    test('formatLength', () {
      expect(UnitConverter.formatLength(92, Units.metric), '92 cm');
      expect(UnitConverter.formatLength(92, Units.imperial), '36.2 in');
    });
  });

  group('height formatting', () {
    test('metric passes through', () {
      expect(UnitConverter.formatHeight(178, Units.metric), '178 cm');
    });

    test('imperial produces feet and inches', () {
      expect(UnitConverter.formatHeight(178, Units.imperial), '5\'10"');
      expect(UnitConverter.formatHeight(183, Units.imperial), '6\'0"');
    });

    test('rounding never yields 12 inches', () {
      // 182.5 cm ≈ 71.85 in → 5'11.85" must round to 6'0", not 5'12".
      expect(UnitConverter.formatHeight(182.5, Units.imperial), '6\'0"');
    });
  });

  group('volume formatting', () {
    test('compacts large values', () {
      expect(UnitConverter.formatVolume(12400, Units.metric), '12.4k kg');
      expect(UnitConverter.formatVolume(950, Units.metric), '950 kg');
    });
  });
}
