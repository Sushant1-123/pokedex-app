import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../intro/intro_painters.dart';

/// Network / API error state (Stitch "03 / Network & API 503 state"): used by
/// the list, telemetry, saved records and the detail screen.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String title;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Sub-Node Synchronization Failed',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: AppColors.crimson.withValues(alpha: .5),
                  ),
                ),
                child: const PokeBallMark(glow: AppColors.crimson),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.crimson,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'RETRY TELEMETRY CONNECTION',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact error for one section of the detail screen.
class SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const SectionError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.crimson),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(
          message,
          style: AppTypography.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
        child: const Text('RETRY', style: AppTypography.label),
      ),
    ],
  );
}

/// Empty search state (Stitch "02 / Empty search state"): radar rings and
/// a single action that clears the query and the type filter.
class EmptyResultsView extends StatelessWidget {
  final String query;
  final String? type;
  final VoidCallback onClear;
  const EmptyResultsView({
    super.key,
    required this.query,
    required this.onClear,
    this.type,
  });

  String get _message {
    final what = switch (type) {
      null => 'specimen',
      final type =>
        '${type[0].toUpperCase()}${type.substring(1)}-type specimen',
    };
    return query.isEmpty
        ? 'No $what is indexed for this filter.'
        : 'No $what matches "$query". Check your spelling or search by '
              'Pokedex number.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(dimension: 120, child: _RadarRings()),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'No Specimen Found Matching Query',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onClear,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(
                  type == null ? 'CLEAR SEARCH' : 'CLEAR SEARCH & FILTERS',
                  style: AppTypography.label.copyWith(color: AppColors.surface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarRings extends StatelessWidget {
  const _RadarRings();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      for (final size in const [120.0, 84.0, 48.0])
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cyan.withValues(alpha: .25)),
          ),
        ),
      const PokeBallMark(
        glow: AppColors.cyan,
        size: AppSizes.illustrationSmall,
      ),
    ],
  );
}

/// Small Poke Ball illustration (the intro's painter) with a soft glow,
/// used on empty and error states.
class PokeBallMark extends StatelessWidget {
  final Color glow;
  final double size;
  const PokeBallMark({
    super.key,
    required this.glow,
    this.size = AppSizes.illustration,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: glow.withValues(alpha: .45), blurRadius: size * .6),
      ],
    ),
    child: const CustomPaint(painter: PokeBallPainter()),
  );
}
