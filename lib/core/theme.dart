import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Material theme assembled from the design tokens, so widgets that rely on
/// theme defaults (buttons, inputs, tooltips) match the Stitch design too.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      brightness: Brightness.dark,
      primary: AppColors.cyan,
      secondary: AppColors.crimson,
      error: AppColors.crimson,
      surface: AppColors.surface,
    );
    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        displaySmall: AppTypography.display,
        headlineSmall: AppTypography.headline,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.titleSmall,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.label,
        labelSmall: AppTypography.caption,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.container,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerColor: AppColors.border,
      tooltipTheme: TooltipThemeData(
        textStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
        decoration: BoxDecoration(
          color: AppColors.containerHigh,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.container,
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.cyan),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
      ),
    );
  }
}

/// Responsive breakpoints for the mobile (2-col), tablet (3-col) and
/// desktop (5-col + sidebar) Stitch frames.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 700;
  static const double desktop = 1200;

  static int columnsFor(double width) {
    if (width >= desktop) return 5;
    if (width >= tablet) return 3;
    return 2;
  }

  static double gridGapFor(double width) =>
      width >= tablet ? AppSpacing.gridGap : AppSpacing.gridGapCompact;

  static double pagePaddingFor(double width) =>
      width >= desktop ? AppSpacing.xxxl : AppSpacing.lg;
}
