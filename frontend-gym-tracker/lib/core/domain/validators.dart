/// Form validators. Each returns null when valid, an error message otherwise,
/// matching the `TextFormField.validator` contract.
abstract final class Validators {
  static final RegExp _email =
      RegExp(r'^[\w.\-+]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)+$');

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final req = required(value, 'Name');
    if (req != null) return req;
    if (value!.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? email(String? value) {
    final req = required(value, 'Email');
    if (req != null) return req;
    if (!_email.hasMatch(value!.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'At least 8 characters';
    if (!value.contains(RegExp(r'[A-Za-z]'))) return 'Include a letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Include a number';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Numeric input inside [min, max]. When [allowEmpty], blank passes.
  static String? numericRange(
    String? value, {
    required String field,
    required double min,
    required double max,
    bool allowEmpty = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : '$field is required';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return 'Enter a valid number';
    if (parsed < min || parsed > max) {
      return '$field must be between ${_fmt(min)} and ${_fmt(max)}';
    }
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  // Canonical ranges (metric).
  static String? age(String? v) =>
      numericRange(v, field: 'Age', min: 13, max: 100);
  static String? heightCm(String? v) =>
      numericRange(v, field: 'Height', min: 100, max: 250);
  static String? weightKg(String? v) =>
      numericRange(v, field: 'Weight', min: 30, max: 300);
  static String? bodyFat(String? v) =>
      numericRange(v, field: 'Body fat', min: 3, max: 60, allowEmpty: true);
}
