import 'package:flutter/material.dart';

/// Central place for app color definitions.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF0B7A75);

  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color primaryRedDark = Color(0xFFE53935);
  static const Color titleRed = Color(0xFF7F0000);

  static const Color success = Color(0xFF2E7D32);
  static const Color magenta = Color(0xFFAD1457);
  static const Color purple = Color(0xFF6A1B9A);
  static const Color danger = Color(0xFFC62828);

  static const Color black87 = Color(0xFF111111);
  static const Color pink50 = Color(0xFFFCE4EC);

  static const Color white = Colors.white;

  /// Helper to create a black overlay color with given opacity.
  static Color overlay(double opacity) => Colors.black.withValues(alpha: opacity);

  // UI helpers
  static const Color buttonBackground = Color.fromARGB(255, 255, 242, 247);
  static const Color buttonShadow = Color.fromARGB(28, 255, 227, 231);
}
