import 'package:flutter/material.dart';

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

  /// Build a TextTheme with explicit sizes using Roboto.
  static TextTheme textTheme() {
    return TextTheme(
      headlineSmall: const TextStyle(
        fontSize: headlineSmall,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: const TextStyle(
        fontSize: titleSmall,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(fontSize: bodyLarge),
      bodyMedium: const TextStyle(fontSize: bodyMedium),
      bodySmall: const TextStyle(fontSize: bodySmall),
      labelSmall: const TextStyle(fontSize: label),
    );
  }
}
