import 'package:flutter/material.dart';

/// Colours from the Google Stitch design system. Surface, container, crimson
/// and cyan come from the Stitch summary; the rest were sampled from the
/// Stitch screenshots in design_reference/.
class AppColors {
  AppColors._();

  static const Color surface = Color(0xFF0B0F17);
  static const Color surfaceSunken = Color(0xFF070A11);
  static const Color container = Color(0xFF181C24);
  static const Color containerHigh = Color(0xFF1F242E);
  static const Color border = Color(0xFF272B34);
  static const Color track = Color(0xFF191D26);
  static const Color gridLine = Color(0xFF171B24);

  static const Color crimson = Color(0xFFEF4444);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color success = Color(0xFF3BA985);
  static const Color warning = Color(0xFFE6B848);

  static const Color textPrimary = Color(0xFFFEFEFF);
  static const Color textSecondary = Color(0xFFCACED8);
  static const Color textMuted = Color(0xFF9097A2);

  /// Glow tones for PokeAPI's species colours, tuned to read on the dark
  /// surface ("black" and "gray" become light enough to glow).
  static const Map<String, Color> speciesGlow = {
    'red': Color(0xFFFF5A5F),
    'blue': Color(0xFF4DA3FF),
    'yellow': Color(0xFFFFD84D),
    'green': Color(0xFF4ADE80),
    'black': Color(0xFF9D8CFF),
    'brown': Color(0xFFD9A066),
    'purple': Color(0xFFC084FC),
    'gray': Color(0xFFB8C4D6),
    'white': Color(0xFFF1F5F9),
    'pink': Color(0xFFF9A8D4),
  };

  /// Neutral used for the lower half of the Poke Ball in the intro.
  static const Color pearl = Color(0xFFE8EAF0);
}

/// 4px spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Gap between grid cards (20px in the tablet frame).
  static const double gridGap = 20;
  static const double gridGapCompact = 12;
}

class AppRadii {
  AppRadii._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;
}

/// Plus Jakarta Sans type scale (bundled in assets/fonts/).
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  /// Upper-case section and field labels.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  /// Large faded dex number behind artwork.
  static const TextStyle watermark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 96,
    height: 1,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// Numeric readouts (dex numbers, stats) with tabular figures.
  static const TextStyle numeric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    color: AppColors.textSecondary,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );
}

/// Durations and distances for the card micro-interactions.
class AppMotion {
  AppMotion._();

  static const Duration hover = Duration(milliseconds: 180);
  static const Duration press = Duration(milliseconds: 110);
  static const Duration hop = Duration(milliseconds: 420);

  /// Each card starts this much after the previous one on a page load...
  static const Duration staggerStep = Duration(milliseconds: 22);

  /// ...and takes this long; the delay stops growing after
  /// [staggerMaxSteps] cards, so a page is in within ~0.5s.
  static const Duration staggerItem = Duration(milliseconds: 240);
  static const int staggerMaxSteps = 12;

  static const double cardLift = 4;
  static const double cardPressScale = .97;
  static const double cardHop = 10;

  /// How far artwork pops out above the top of its container.
  static const double artworkOverlap = 14;
}

/// Base-stat colour bands: low stats are muted, mid stats cyan, high
/// stats crimson.
class AppStatScale {
  AppStatScale._();

  static const int mid = 60;
  static const int high = 100;

  static Color colorFor(int value) => value >= high
      ? AppColors.crimson
      : value >= mid
      ? AppColors.cyan
      : AppColors.textMuted;
}

/// Sizes of the small illustrations on empty and error states.
class AppSizes {
  AppSizes._();

  static const double illustration = 44;
  static const double illustrationSmall = 30;

  /// Type chart cell and row-header sizes.
  static const double chartCell = 34;
  static const double chartHeader = 84;

  /// Compare Lab radar chart.
  static const double radarChart = 260;

  /// Minimum touch target for phone controls.
  static const double tapTarget = 44;

  /// Numbered pager buttons, their icons, and the room one Prev/Next
  /// button needs when deciding how many page numbers fit.
  static const double pagerButton = 36;
  static const double pagerIcon = 18;
  static const double pagerNavWidth = 84;

  /// Page-jump sheet: columns of page numbers and its maximum height as a
  /// fraction of the screen.
  static const int pageJumpColumns = 5;
  static const double sheetHeight = .6;
}
