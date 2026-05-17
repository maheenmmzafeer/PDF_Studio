import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color red = Color(0xFFB71C1C);
  static const Color turquoise = Color(0xFF0B7A75);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}

class AppGradients {
  static const LinearGradient redToWhite = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFB71C1C), Color(0xFFFFEBEE)],
  );

  static const LinearGradient redCardSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x22B71C1C), Colors.white],
  );

  static const LinearGradient turquoiseCardSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x220B7A75), Colors.white],
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.red,
      onPrimary: AppPalette.white,
      secondary: AppPalette.turquoise,
      onSecondary: AppPalette.white,
      error: Colors.red,
      onError: AppPalette.white,
      surface: AppPalette.white,
      onSurface: AppPalette.black,
    ),
    useMaterial3: true,
    textTheme: GoogleFonts.quicksandTextTheme(),
  );
}
