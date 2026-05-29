
import 'package:flutter/material.dart';

class EinkTheme {
  static const Color paper = Color(0xFFF7F6F0);
  static const Color ink = Color(0xFF222222);
  static const Color softInk = Color(0xFF555555);
  static const Color rule = Color(0xFFB7B7B7);
  static const Color correct = Color(0xFFB7D7B2);
  static const Color partial = Color(0xFFD9D29A);
  static const Color needsPractice = Color(0xFFD7B2B2);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ink,
      brightness: Brightness.light,
      surface: paper,
    );
    return ThemeData(
      colorScheme: scheme.copyWith(
        primary: ink,
        secondary: softInk,
        surface: paper,
        error: needsPractice,
      ),
      scaffoldBackgroundColor: paper,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
      }),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(color: ink, height: 1.45),
        bodyMedium: TextStyle(color: ink, height: 1.4),
      ),
    );
  }
}

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}
