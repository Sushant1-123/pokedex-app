import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// The coordinate grid behind artwork in the Stitch cards and the detail
/// viewport.
class GridBackground extends StatelessWidget {
  final Widget child;
  final double spacing;
  final Color color;
  final BorderRadius borderRadius;

  /// Optional colour washed in from the top edge.
  final Color? tint;

  const GridBackground({
    super.key,
    required this.child,
    this.spacing = 18,
    this.color = AppColors.gridLine,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.md)),
    this.tint,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          switch (tint) {
            final Color tint => Color.alphaBlend(
              tint.withValues(alpha: .22),
              AppColors.surface,
            ),
            null => AppColors.surface,
          },
          AppColors.surface,
        ],
        stops: const [0, .65],
      ),
      borderRadius: borderRadius,
      border: Border.all(color: AppColors.border),
    ),
    child: ClipRRect(
      borderRadius: borderRadius,
      child: CustomPaint(
        painter: GridPainter(spacing: spacing, color: color),
        child: child,
      ),
    ),
  );
}

class GridPainter extends CustomPainter {
  final double spacing;
  final Color color;
  const GridPainter({required this.spacing, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.spacing != spacing || old.color != color;
}
