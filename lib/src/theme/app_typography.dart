import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography and concrete font sizes for the app.
class AppTypography {
  AppTypography._();

  // Concrete sizes (in logical pixels). Keep the set small and consistent.
  static const double headlineSmall = 20.0;
  static const double titleSmall = 16.0;
  static const double bodyLarge = 14.0;
  static const double bodyMedium = 13.0;
  static const double bodySmall = 12.0;
  static const double label = 12.0;

  /// Build a TextTheme with explicit sizes using YoungSerif.
  static TextTheme textTheme() {
    final base = GoogleFonts.youngSerifTextTheme();
    return TextTheme(
      headlineSmall: (base.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: headlineSmall,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: (base.titleSmall ?? const TextStyle()).copyWith(
        fontSize: titleSmall,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: (base.bodyLarge ?? const TextStyle()).copyWith(
        fontSize: bodyLarge,
      ),
      bodyMedium: (base.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: bodyMedium,
      ),
      bodySmall: (base.bodySmall ?? const TextStyle()).copyWith(
        fontSize: bodySmall,
      ),
      labelSmall: (base.labelSmall ?? const TextStyle()).copyWith(
        fontSize: label,
      ),
    );
  }
}
