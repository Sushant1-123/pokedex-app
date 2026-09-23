import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';

/// Skeleton grid shown while the list is loading — required by the brief
/// ("loading skeletons ... must be designed, not just the happy path").
class PokemonListSkeleton extends StatelessWidget {
  const PokemonListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = Breakpoints.columnsFor(width);
    return Shimmer.fromColors(
      baseColor: AppTheme.panel,
      highlightColor: AppTheme.panelRaised,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: columns * 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: width >= Breakpoints.desktop
              ? 0.94
              : width >= Breakpoints.tablet
              ? 0.88
              : 0.82,
        ),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: AppTheme.panel,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the detail screen.
class PokemonDetailSkeleton extends StatelessWidget {
  const PokemonDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.panel,
      highlightColor: AppTheme.panelRaised,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 24, width: 160, color: Colors.white),
            const SizedBox(height: 12),
            Container(height: 16, width: 100, color: Colors.white),
            const SizedBox(height: 24),
            for (var i = 0; i < 6; i++) ...[
              Container(height: 14, color: Colors.white),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
