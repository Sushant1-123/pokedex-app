import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Rounded container used for every section in the Stitch frames.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.glow,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.container,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        if (glow case final Color glow)
          BoxShadow(
            color: glow.withValues(alpha: .12),
            blurRadius: 40,
            spreadRadius: -8,
          ),
      ],
    ),
    child: child,
  );
}

/// Panel heading shared by every section: an accent tick, optional icon,
/// small upper-case label, optional trailing widget, and a thin accent line
/// underneath.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: AppSpacing.xxs + 1,
              height: AppSpacing.md + 2,
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.cyan),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.cyan.withValues(alpha: .6),
                AppColors.border,
                AppColors.border.withValues(alpha: 0),
              ],
              stops: const [0, .35, 1],
            ),
          ),
        ),
      ],
    ),
  );
}
