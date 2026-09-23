import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/design_tokens.dart';

/// Shimmer wrapper in the design's surface colours.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.container,
    highlightColor: AppColors.containerHigh,
    child: child,
  );
}

/// A single grey block inside a [SkeletonShimmer].
class SkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadii.sm,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: AppColors.container,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Skeleton grid shown while a directory page loads, laid out like the real
/// cards (Stitch "01 / Loading skeleton state").
class PokemonGridSkeleton extends StatelessWidget {
  final int columns;
  final double gap;
  final double cardExtent;
  final int count;

  const PokemonGridSkeleton({
    super.key,
    required this.columns,
    required this.gap,
    required this.cardExtent,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => SliverGrid(
    delegate: SliverChildBuilderDelegate(
      (context, index) => const _CardSkeleton(),
      childCount: count,
    ),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
      mainAxisExtent: cardExtent,
    ),
  );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.lg),
    ),
    child: const SkeletonShimmer(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBlock(height: 10, width: 48),
            SizedBox(height: AppSpacing.sm),
            SkeletonBlock(height: 16, width: 96),
            SizedBox(height: AppSpacing.sm),
            SkeletonBlock(height: 14, width: 64),
            SizedBox(height: AppSpacing.md),
            Expanded(child: SkeletonBlock(height: 0, radius: AppRadii.md)),
            SizedBox(height: AppSpacing.md),
            SkeletonBlock(height: 6),
            SizedBox(height: AppSpacing.sm),
            SkeletonBlock(height: 6),
          ],
        ),
      ),
    ),
  );
}

/// Skeleton for one detail-screen section.
class SectionSkeleton extends StatelessWidget {
  final int lines;
  const SectionSkeleton({super.key, this.lines = 3});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          SkeletonBlock(height: 14, width: i.isEven ? null : 180),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}
