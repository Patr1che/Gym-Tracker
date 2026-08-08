/// Spacing / radius / blur tokens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal screen padding.
  static const double screenH = 20;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 100;
}

abstract final class AppBlur {
  /// Max sigma used for real BackdropFilter blur (static surfaces only).
  static const double glass = 12;
}
