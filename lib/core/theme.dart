import 'package:flutter/material.dart';

/// Central theme so the list/detail screens and widgets stay visually consistent
/// without every widget hardcoding its own colors and text styles.
class AppTheme {
  AppTheme._();

  static const Color ink = Color(0xFF0B0E0B);
  static const Color panel = Color(0xFF121712);
  static const Color panelRaised = Color(0xFF1A211A);
  static const Color line = Color(0xFF303930);
  static const Color signal = Color(0xFFD7FF4F);
  static const Color paper = Color(0xFFE7EBDD);
  static const Color muted = Color(0xFF879184);
  static const Color alert = Color(0xFFFF765E);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: signal,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      fontFamily: 'monospace',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: paper, fontSize: 14),
        bodyMedium: TextStyle(color: muted, fontSize: 13),
        titleLarge: TextStyle(color: paper, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: paper, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          borderSide: BorderSide(color: signal),
        ),
        prefixIconColor: muted,
        hintStyle: const TextStyle(color: muted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

/// Simple responsive breakpoints used to switch grid column counts.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 700;
  static const double desktop = 1100;

  static int columnsFor(double width) {
    if (width >= desktop) return 5;
    if (width >= tablet) return 3;
    return 2;
  }
}
