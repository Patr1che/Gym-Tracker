import '../models/enums.dart';

/// All storage and domain logic is metric (kg / cm). Conversion happens ONLY
/// here, at the presentation edge — never store converted values.
abstract final class UnitConverter {
  static const double _lbPerKg = 2.2046226218;
  static const double _cmPerIn = 2.54;

  static double kgToLb(double kg) => kg * _lbPerKg;
  static double lbToKg(double lb) => lb / _lbPerKg;
  static double cmToIn(double cm) => cm / _cmPerIn;
  static double inToCm(double inches) => inches * _cmPerIn;

  /// '82.5 kg' / '181.9 lb'. Whole numbers drop the decimal.
  static String formatWeight(double kg, Units units, {bool withUnit = true}) {
    final value = units == Units.metric ? kg : kgToLb(kg);
    final text = _trim(value);
    if (!withUnit) return text;
    return '$text ${weightUnit(units)}';
  }

  static String weightUnit(Units units) =>
      units == Units.metric ? 'kg' : 'lb';

  static String lengthUnit(Units units) => units == Units.metric ? 'cm' : 'in';

  /// Parses user weight input in the user's display unit, returns kg.
  static double? parseWeight(String text, Units units) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null) return null;
    return units == Units.metric ? value : lbToKg(value);
  }

  /// '92.0 cm' / '36.2 in' for girth measurements.
  static String formatLength(double cm, Units units, {bool withUnit = true}) {
    final value = units == Units.metric ? cm : cmToIn(cm);
    final text = _trim(value);
    if (!withUnit) return text;
    return '$text ${lengthUnit(units)}';
  }

  /// Parses girth/length input in the user's display unit, returns cm.
  static double? parseLength(String text, Units units) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null) return null;
    return units == Units.metric ? value : inToCm(value);
  }

  /// '178 cm' or '5\'10"'.
  static String formatHeight(double cm, Units units) {
    if (units == Units.metric) return '${_trim(cm)} cm';
    final totalInches = cmToIn(cm);
    var feet = totalInches ~/ 12;
    var inches = (totalInches - feet * 12).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    return "$feet'$inches\"";
  }

  /// Compact volume display: '12.4k kg' above 10k.
  static String formatVolume(double kg, Units units) {
    final value = units == Units.metric ? kg : kgToLb(kg);
    final unit = weightUnit(units);
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k $unit';
    }
    return '${_trim(value)} $unit';
  }

  static String _trim(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    return rounded.toStringAsFixed(1);
  }
}
