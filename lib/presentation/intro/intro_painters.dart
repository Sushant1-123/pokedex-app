import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// A Poke Ball that can spin, blink its button and split into two halves.
/// Also used, closed and still, as the app logo.
class PokeBallPainter extends CustomPainter {
  /// Spin / wobble angle in radians, around [pivot].
  final double rotation;

  /// How far the halves have moved apart, in ball radii.
  final double split;

  /// 0..1 glow of the centre button.
  final double buttonGlow;

  /// Rotation pivot as a fraction of the size (default: centre).
  final Offset pivot;

  const PokeBallPainter({
    this.rotation = 0,
    this.split = 0,
    this.buttonGlow = 0,
    this.pivot = const Offset(.5, .5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    canvas.save();
    final p = Offset(size.width * pivot.dx, size.height * pivot.dy);
    canvas
      ..translate(p.dx, p.dy)
      ..rotate(rotation)
      ..translate(-p.dx, -p.dy);

    if (split == 0) {
      _drawBall(canvas, center, r);
    } else {
      final gap = split * r;
      for (final (top, dy) in [(true, -gap), (false, gap)]) {
        canvas
          ..save()
          ..translate(0, dy)
          ..clipRect(
            top
                ? Rect.fromLTRB(
                    center.dx - r * 2,
                    center.dy - r * 2,
                    center.dx + r * 2,
                    center.dy,
                  )
                : Rect.fromLTRB(
                    center.dx - r * 2,
                    center.dy,
                    center.dx + r * 2,
                    center.dy + r * 2,
                  ),
          );
        _drawBall(canvas, center, r);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  void _drawBall(Canvas canvas, Offset c, double r) {
    final ball = Rect.fromCircle(center: c, radius: r);
    final upper = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.55),
        radius: .9,
        colors: [
          Color.lerp(AppColors.crimson, AppColors.textPrimary, .35)!,
          AppColors.crimson,
          Color.lerp(AppColors.crimson, AppColors.surfaceSunken, .6)!,
        ],
        stops: const [0, .45, 1],
      ).createShader(ball);
    final lower = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.3, .2),
        radius: 1,
        colors: [
          AppColors.pearl,
          Color.lerp(AppColors.pearl, AppColors.surface, .45)!,
        ],
      ).createShader(ball);
    canvas
      ..drawArc(ball, math.pi, math.pi, true, upper)
      ..drawArc(ball, 0, math.pi, true, lower);

    final ink = Paint()..color = AppColors.surface;
    final band = r * .16;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: r * 2, height: band),
      ink,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .08
        ..color = AppColors.surface,
    );

    if (buttonGlow > 0) {
      canvas.drawCircle(
        c,
        r * .42,
        Paint()
          ..color = AppColors.cyan.withValues(alpha: .55 * buttonGlow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .25),
      );
    }
    canvas
      ..drawCircle(c, r * .3, ink)
      ..drawCircle(
        c,
        r * .19,
        Paint()
          ..color = Color.lerp(AppColors.pearl, AppColors.cyan, buttonGlow)!,
      );
  }

  @override
  bool shouldRepaint(PokeBallPainter old) =>
      old.rotation != rotation ||
      old.split != split ||
      old.buttonGlow != buttonGlow ||
      old.pivot != pivot;
}

/// Perspective floor grid for the intro scene.
class FloorGridPainter extends CustomPainter {
  /// Horizon as a fraction of the height.
  final double horizon;
  const FloorGridPainter({required this.horizon});

  @override
  void paint(Canvas canvas, Size size) {
    final y0 = size.height * horizon;
    final line = Paint()
      ..color = AppColors.cyan.withValues(alpha: .08)
      ..strokeWidth = 1;
    final center = size.width / 2;
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(
        Offset(center + i * size.width * .02, y0),
        Offset(center + i * size.width * .16, size.height),
        line,
      );
    }
    for (var i = 1; i <= 8; i++) {
      final t = i / 8;
      final y = y0 + (size.height - y0) * t * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      Offset(0, y0),
      Offset(size.width, y0),
      Paint()
        ..color = AppColors.cyan.withValues(alpha: .25)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(FloorGridPainter old) => old.horizon != horizon;
}
