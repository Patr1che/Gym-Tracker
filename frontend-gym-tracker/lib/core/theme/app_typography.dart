import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Space Grotesk for display/stat numbers, Manrope for everything else.
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    final body = GoogleFonts.manropeTextTheme();
    TextStyle display(double size, FontWeight weight, {double? spacing}) =>
        GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: weight,
          color: primary,
          letterSpacing: spacing,
        );
    TextStyle manrope(double size, FontWeight weight, Color color,
            {double? height}) =>
        GoogleFonts.manrope(
            fontSize: size, fontWeight: weight, color: color, height: height);

    return body.copyWith(
      displayLarge: display(44, FontWeight.w700, spacing: -1),
      displayMedium: display(36, FontWeight.w700, spacing: -0.5),
      displaySmall: display(28, FontWeight.w700),
      headlineLarge: display(26, FontWeight.w700),
      headlineMedium: display(22, FontWeight.w700),
      headlineSmall: display(19, FontWeight.w600),
      titleLarge: manrope(18, FontWeight.w700, primary),
      titleMedium: manrope(16, FontWeight.w600, primary),
      titleSmall: manrope(14, FontWeight.w600, primary),
      bodyLarge: manrope(16, FontWeight.w500, primary, height: 1.5),
      bodyMedium: manrope(14, FontWeight.w500, secondary, height: 1.5),
      bodySmall: manrope(12, FontWeight.w500, secondary, height: 1.4),
      labelLarge: manrope(15, FontWeight.w700, primary),
      labelMedium: manrope(13, FontWeight.w600, secondary),
      labelSmall: manrope(11, FontWeight.w600, secondary),
    );
  }

  /// Big stat number style (dashboard tiles, timer).
  static TextStyle stat(BuildContext context, {double size = 26}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: -0.5,
      );
}
