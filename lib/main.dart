import 'package:flutter/material.dart';
import 'src/home.dart';
import 'src/theme/app_colors.dart';
import 'src/theme/app_typography.dart';

void main() {
  runApp(const LocalPdfStudioApp());
}

class LocalPdfStudioApp extends StatelessWidget {
  const LocalPdfStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.seed),
        useMaterial3: true,
        textTheme: AppTypography.textTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}
