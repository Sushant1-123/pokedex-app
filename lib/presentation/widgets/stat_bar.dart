import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Short labels used across the cards and the stat table.
String statLabel(String name) => switch (name) {
  'hp' => 'HP',
  'attack' => 'ATK',
  'defense' => 'DEF',
  'special-attack' => 'SP.A',
  'special-defense' => 'SP.D',
  'speed' => 'SPE',
  _ => name.toUpperCase(),
};

/// Animated base-stat bar for the detail screen, coloured by value through
/// [AppStatScale] (low muted, mid cyan, high crimson).
class StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.maxValue = 255,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    final color = AppStatScale.colorFor(value);
    final textColor = value >= AppStatScale.high
        ? AppColors.crimson
        : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: textColor),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toString().padLeft(3, '0'),
              style: AppTypography.numeric.copyWith(color: textColor),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, animatedFraction, _) =>
                    LinearProgressIndicator(
                      value: animatedFraction,
                      minHeight: 8,
                      backgroundColor: AppColors.track,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact labelled bar for card footers ("HP BASE 078 / 255").
class MiniStatBar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;

  const MiniStatBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppTypography.numeric.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: AppColors.track,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );
}
