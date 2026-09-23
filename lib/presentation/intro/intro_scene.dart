import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import 'intro_painters.dart';

/// The trainer artwork and the measured points in it (fractions of the
/// image's width/height).
class TrainerArt {
  TrainerArt._();

  static const asset = 'assets/images/intro/trainer.webp';

  /// 800 x 1920 source image.
  static const aspectRatio = 800 / 1920;

  /// Centre of the raised, gloved hand at the cap brim. The ball is thrown
  /// from here. The arm overlaps the head and cap, so it can't be cut out
  /// cleanly and the whole figure is animated instead.
  static const hand = Offset(.73, .145);
}

/// Phases of the throw, as fractions of the play animation (0..1).
class IntroTimeline {
  IntroTimeline._();

  static const enter = (0.0, .14);
  static const windUp = (.16, .30);
  static const throwing = (.30, .38);

  /// The moment the ball leaves the hand.
  static const release = .35;
  static const exit = (.46, .64);
  static const flight = (release, .62);
  static const bounce = (.62, .72);
  static const wobble = (.72, 1.0);

  static double phase((double, double) span, double t, [Curve? curve]) {
    final (start, end) = span;
    final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve?.transform(v) ?? v;
  }
}

/// Where the trainer is at a moment in time. [angle] rotates around the
/// feet (negative leans back, positive leans into the throw); the scale is
/// a temporary squash/stretch and always returns to 1.
typedef TrainerPose = ({
  double dx,
  double angle,
  double scaleX,
  double scaleY,
  double opacity,
});

/// Screen-relative geometry of the intro, so it fills phones and desktops
/// alike without cropping or stretching the artwork.
class IntroLayout {
  final Size size;
  const IntroLayout(this.size);

  double get ballRadius => (size.shortestSide * .06).clamp(16.0, 56.0);

  /// Where the ball lands: the centre of the screen.
  Offset get landing => size.center(Offset.zero);

  /// The trainer at rest: standing in the lower-left foreground, as tall as
  /// the screen allows while staying clear of the landing spot.
  Rect get trainerRect {
    final height = math.min(
      size.height * .66,
      size.width * .3 / TrainerArt.aspectRatio,
    );
    final width = height * TrainerArt.aspectRatio;
    final feet = size.height * .94;
    final left = math.max(size.width * .07, AppSpacing.lg);
    return Rect.fromLTWH(left, feet - height, width, height);
  }

  TrainerPose poseAt(double t) {
    final rect = trainerRect;
    final enter = IntroTimeline.phase(
      IntroTimeline.enter,
      t,
      Curves.easeOutBack,
    );
    final windUp = IntroTimeline.phase(
      IntroTimeline.windUp,
      t,
      Curves.easeInOut,
    );
    final thrown = IntroTimeline.phase(
      IntroTimeline.throwing,
      t,
      Curves.easeOutCubic,
    );
    final exit = IntroTimeline.phase(IntroTimeline.exit, t, Curves.easeIn);

    final lean = thrown > 0
        ? lerpDouble(-.14, .16, thrown)!
        : lerpDouble(0, -.14, windUp)!;
    return (
      dx:
          -(1 - enter) * (rect.right + AppSpacing.xxxl) +
          thrown * rect.width * .22 -
          exit * rect.width * .35,
      angle: lerpDouble(lean, 0, exit)!,
      scaleX: thrown > 0
          ? lerpDouble(1.03, 1, thrown)!
          : lerpDouble(1, 1.03, windUp)!,
      scaleY: thrown > 0
          ? lerpDouble(.96, 1, thrown)! + math.sin(thrown * math.pi) * .05
          : lerpDouble(1, .96, windUp)!,
      opacity:
          (IntroTimeline.phase(IntroTimeline.enter, t) * 3).clamp(0.0, 1.0) *
          (1 - exit),
    );
  }

  /// The hand's position on screen with [poseAt] applied, mirroring the
  /// Transform used to draw the trainer (pivot at the feet).
  Offset handAt(double t) {
    final rect = trainerRect;
    final pose = poseAt(t);
    final pivot = rect.bottomCenter;
    final local =
        rect.topLeft +
        Offset(
          TrainerArt.hand.dx * rect.width,
          TrainerArt.hand.dy * rect.height,
        ) -
        pivot;
    final x = local.dx * pose.scaleX;
    final y = local.dy * pose.scaleY;
    final cos = math.cos(pose.angle);
    final sin = math.sin(pose.angle);
    return pivot + Offset(pose.dx + x * cos - y * sin, x * sin + y * cos);
  }

  /// Transform for the trainer image, matching [handAt].
  Matrix4 trainerTransform(TrainerPose pose) => Matrix4.identity()
    ..translateByDouble(pose.dx, 0, 0, 1)
    ..rotateZ(pose.angle)
    ..scaleByDouble(pose.scaleX, pose.scaleY, 1, 1);
}

/// Dark scene, floor grid, speed lines and dust, behind the trainer. While
/// revealing it becomes two panels sliding apart from the ball's centre
/// line, uncovering the app.
class IntroBackdropPainter extends CustomPainter {
  final double play;
  final double reveal;
  const IntroBackdropPainter({required this.play, required this.reveal});

  @override
  void paint(Canvas canvas, Size size) {
    final layout = IntroLayout(size);
    final landing = layout.landing;
    final ballR = layout.ballRadius;
    final gap =
        Curves.easeInCubic.transform(reveal) * (size.height / 2 + ballR * 2);

    final fill = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -.1),
        radius: 1.1,
        colors: [
          AppColors.container,
          AppColors.surface,
          AppColors.surfaceSunken,
        ],
        stops: [0, .55, 1],
      ).createShader(Offset.zero & size);
    final top = Rect.fromLTRB(0, 0, size.width, landing.dy - gap);
    final bottom = Rect.fromLTRB(0, landing.dy + gap, size.width, size.height);
    canvas
      ..drawRect(top, fill)
      ..drawRect(bottom, fill)
      ..save()
      ..clipRect(bottom)
      ..translate(0, gap);
    FloorGridPainter(
      horizon: (landing.dy + ballR) / size.height,
    ).paint(canvas, size);
    canvas.restore();

    if (gap > 0) {
      final seam = Paint()
        ..color = AppColors.cyan.withValues(alpha: .6)
        ..strokeWidth = 1.5;
      canvas
        ..drawLine(top.bottomLeft, top.bottomRight, seam)
        ..drawLine(bottom.topLeft, bottom.topRight, seam);
      _paintRevealFlash(canvas, size, landing);
      return;
    }
    _paintSpeedLines(canvas, layout);
    _paintDust(canvas, layout);
  }

  /// Anime speed lines: horizontal streaks while he dashes in, and a fan of
  /// streaks behind him during the throw.
  void _paintSpeedLines(Canvas canvas, IntroLayout layout) {
    final rect = layout.trainerRect;
    final pose = layout.poseAt(play);
    final dash = 1 - IntroTimeline.phase(IntroTimeline.enter, play);
    final throwing = math.sin(
      IntroTimeline.phase(IntroTimeline.throwing, play) * math.pi,
    );
    final line = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = rect.top + rect.height * (.12 + i * .09);
      final length = rect.width * (.9 + (i % 3) * .5);
      final right = rect.left + pose.dx + rect.width * (.2 + (i % 2) * .15);
      if (dash > 0 && dash < 1) {
        line
          ..strokeWidth = 2 + (i % 3).toDouble()
          ..color = AppColors.cyan.withValues(alpha: .35 * dash);
        canvas.drawLine(Offset(right - length, y), Offset(right, y), line);
      }
      if (throwing > 0) {
        line
          ..strokeWidth = 1.5 + (i % 2).toDouble()
          ..color = AppColors.textPrimary.withValues(alpha: .28 * throwing);
        final start = Offset(rect.left + pose.dx - rect.width * .1, y);
        canvas.drawLine(
          start,
          start.translate(-length * .8, -length * .12 * (i - 4) / 4),
          line,
        );
      }
    }
  }

  /// Dust puffs at the feet as he skids to a stop.
  void _paintDust(Canvas canvas, IntroLayout layout) {
    final settle = IntroTimeline.phase((.08, .24), play);
    if (settle <= 0 || settle >= 1) return;
    final rect = layout.trainerRect;
    final puff = Paint()
      ..color = AppColors.textMuted.withValues(alpha: .35 * (1 - settle))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * .03);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(
          rect.left + rect.width * (.15 + i * .18) - settle * rect.width * .25,
          rect.bottom - rect.width * .04 * (1 + i % 2) * settle,
        ),
        rect.width * (.05 + settle * .07),
        puff,
      );
    }
  }

  /// Crimson/cyan burst as the ball opens.
  void _paintRevealFlash(Canvas canvas, Size size, Offset landing) {
    final strength = math.sin(math.min(reveal * 1.6, 1) * math.pi);
    final radius = size.longestSide * (.15 + reveal * .7);
    canvas.drawCircle(
      landing,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.textPrimary.withValues(alpha: .9 * strength),
            AppColors.cyan.withValues(alpha: .55 * strength),
            AppColors.crimson.withValues(alpha: .35 * strength),
            AppColors.crimson.withValues(alpha: 0),
          ],
          stops: const [0, .25, .6, 1],
        ).createShader(Rect.fromCircle(center: landing, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(IntroBackdropPainter old) =>
      old.play != play || old.reveal != reveal;
}

/// The Poke Ball (in hand, in flight, landed, splitting) and the hand
/// flash, drawn above the trainer.
class IntroForegroundPainter extends CustomPainter {
  final double play;
  final double reveal;
  const IntroForegroundPainter({required this.play, required this.reveal});

  @override
  void paint(Canvas canvas, Size size) {
    final layout = IntroLayout(size);
    final ballR = layout.ballRadius;
    final landing = layout.landing;
    final release = layout.handAt(IntroTimeline.release);
    _paintHandFlash(canvas, release, ballR);

    if (reveal > 0 || play >= IntroTimeline.bounce.$1) {
      _paintLanded(canvas, landing, ballR, size);
      return;
    }
    if (play < IntroTimeline.release) {
      final appear = IntroTimeline.phase(IntroTimeline.windUp, play);
      if (appear > 0) {
        _drawBall(
          canvas,
          layout.handAt(play),
          ballR * .8 * appear,
          const PokeBallPainter(),
        );
      }
      return;
    }
    _paintFlight(canvas, release, landing, ballR);
  }

  void _paintHandFlash(Canvas canvas, Offset hand, double ballR) {
    final flash = IntroTimeline.phase((.33, .43), play);
    if (flash <= 0 || flash >= 1) return;
    final strength = math.sin(flash * math.pi);
    final radius = ballR * (1.2 + flash * 2.4);
    canvas.drawCircle(
      hand,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.textPrimary.withValues(alpha: .85 * strength),
            AppColors.cyan.withValues(alpha: .4 * strength),
            AppColors.cyan.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: hand, radius: radius)),
    );
  }

  /// Quadratic Bezier arc from the hand to the landing spot, spinning, with
  /// a fading trail.
  void _paintFlight(Canvas canvas, Offset from, Offset landing, double ballR) {
    final flight = IntroTimeline.phase(IntroTimeline.flight, play);
    final control = Offset(
      lerpDouble(from.dx, landing.dx, .45)!,
      math.min(from.dy, landing.dy) - landing.dy * .6,
    );
    Offset along(double t) {
      final u = 1 - t;
      return from * (u * u) + control * (2 * u * t) + landing * (t * t);
    }

    double radiusAt(double t) => lerpDouble(ballR * .8, ballR, t)!;
    for (var k = 6; k >= 1; k--) {
      final t = flight - k * .03;
      if (t <= 0) continue;
      canvas.drawCircle(
        along(t),
        radiusAt(t) * (1 - k * .08),
        Paint()..color = AppColors.cyan.withValues(alpha: .12 * (1 - k / 7)),
      );
    }
    _paintShadow(canvas, landing, ballR, (1 - flight) * landing.dy);
    _drawBall(
      canvas,
      along(flight),
      radiusAt(flight),
      PokeBallPainter(rotation: flight * 5 * math.pi),
    );
  }

  /// Bounce, three wobbles pivoting on the floor with a blinking button,
  /// then the split.
  void _paintLanded(Canvas canvas, Offset landing, double ballR, Size size) {
    final bounce = IntroTimeline.phase(IntroTimeline.bounce, play);
    final wobble = IntroTimeline.phase(IntroTimeline.wobble, play);
    final hop = math.sin(bounce * math.pi) * ballR * 1.2 * (1 - bounce * .5);
    final gap =
        Curves.easeInCubic.transform(reveal) * (size.height / 2 + ballR * 2);
    _paintShadow(canvas, landing, ballR, hop);
    _drawBall(
      canvas,
      landing.translate(0, -hop),
      ballR,
      PokeBallPainter(
        rotation: reveal > 0
            ? 0
            : math.sin(wobble * 3 * 2 * math.pi) * .32 * (1 - wobble * .5),
        pivot: const Offset(.5, 1),
        buttonGlow: reveal > 0
            ? 1
            : math.pow(math.sin(wobble * 3 * math.pi), 2).toDouble(),
        split: gap / ballR,
      ),
    );
  }

  /// Floor shadow that shrinks and fades the higher the ball is.
  void _paintShadow(
    Canvas canvas,
    Offset landing,
    double ballR,
    double height,
  ) {
    final lift = (height / (ballR * 6)).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: landing.translate(0, ballR * .95),
        width: ballR * 1.9 * (1 - lift * .6),
        height: ballR * .45 * (1 - lift * .6),
      ),
      Paint()
        ..color = AppColors.surfaceSunken.withValues(alpha: .55 * (1 - lift))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ballR * .15),
    );
  }

  void _drawBall(
    Canvas canvas,
    Offset center,
    double radius,
    PokeBallPainter ball,
  ) {
    canvas
      ..save()
      ..translate(center.dx - radius, center.dy - radius);
    ball.paint(canvas, Size.square(radius * 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(IntroForegroundPainter old) =>
      old.play != play || old.reveal != reveal;
}
