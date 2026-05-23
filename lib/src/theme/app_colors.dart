import 'package:flutter/material.dart';

/// Central place for app color definitions.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFFB71C1C);

  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color primaryRedDark = Color(0xFFE53935);
  static const Color titleRed = Color(0xFF7F0000);

  static const Color success = Color(0xFFD32F2F);
  static const Color magenta = Color(0xFFEF5350);
  static const Color purple = Color(0xFFE57373);
  static const Color danger = Color(0xFF7F0000);

  static const Color black87 = Color(0xFF111111);
  static const Color pink50 = Color(0xFFFCE4EC);

  static const Color white = Colors.white;

  /// Helper to create a black overlay color with given opacity.
  static Color overlay(double opacity) => Colors.black.withValues(alpha: opacity);

  // UI helpers
  static const Color buttonBackground = Color.fromARGB(255, 255, 239, 239);
  static const Color buttonShadow = Color.fromARGB(28, 183, 28, 28);
}
