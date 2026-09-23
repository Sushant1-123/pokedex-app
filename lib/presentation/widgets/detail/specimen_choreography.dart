import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';

/// One frame of the Pokemon's motion in the viewport. Offsets are fractions
/// of the artwork size (negative [dy] is up); [angle] leans around the feet
/// (positive leans forward, to the right). [trail], [ring] and [flash] are
/// 0..1 strengths of the motion trail, floor ring and impact flash.
typedef SpecimenFrame = ({
  double dx,
  double dy,
  double scaleX,
  double scaleY,
  double angle,
  double trail,
  double ring,
  double flash,
});

/// The moves the Pokemon can do; taps alternate between them.
enum SpecimenMove { jump, kick }

/// Pure motion curves for the detail viewport, kept free of widgets so the
/// timing and state logic can be tested directly.
class SpecimenChoreography {
  SpecimenChoreography._();

  /// Run in, jump, land, kick, settle.
  static const entranceDuration = Duration(milliseconds: 1500);
  static const jumpDuration = Duration(milliseconds: 650);
  static const kickDuration = Duration(milliseconds: 550);

  /// Standing still: where every move ends and where reduce motion stays.
  static const SpecimenFrame rest = (
    dx: 0,
    dy: 0,
    scaleX: 1,
    scaleY: 1,
    angle: 0,
    trail: 0,
    ring: 0,
    flash: 0,
  );

  static double _span(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  /// The entrance at progress [t] (0..1). With [reducedMotion] the Pokemon
  /// is simply at rest (the widget fades it in instead).
  static SpecimenFrame entrance(double t, {bool reducedMotion = false}) {
    if (reducedMotion || t >= 1) return rest;
    // a) Dash in from the left edge with a trail.
    if (t < .3) {
      final p = Curves.easeOutCubic.transform(_span(t, 0, .3));
      return (
        dx: lerpDouble(-1.3, 0, p)!,
        dy: 0,
        scaleX: lerpDouble(1.12, 1, p)!,
        scaleY: lerpDouble(.92, 1, p)!,
        angle: .12 * (1 - p),
        trail: 1 - p * .6,
        ring: 0,
        flash: 0,
      );
    }
    // b) Jump and land with squash and stretch and a floor ring.
    if (t < .7) {
      final jump = jumpAt(_span(t, .3, .7));
      return (
        dx: jump.dx,
        dy: jump.dy,
        scaleX: jump.scaleX,
        scaleY: jump.scaleY,
        angle: jump.angle,
        trail: jump.trail + .4 * (1 - _span(t, .3, .4)),
        ring: jump.ring,
        flash: 0,
      );
    }
    // c) Lunge forward with an impact flash, d) then settle.
    return kickAt(_span(t, .7, 1));
  }

  /// A jump at progress [t]: crouch, rise (stretched), land (squashed),
  /// ring on the floor at touchdown.
  static SpecimenFrame jumpAt(double t) {
    final air = _span(t, .15, .8);
    final height = math.sin(air * math.pi);
    final crouch = t < .15 ? math.sin(_span(t, 0, .15) * math.pi) : 0.0;
    final land = t > .8 ? math.sin(_span(t, .8, 1) * math.pi) : 0.0;
    final squash = math.max(crouch, land);
    final stretch = air > 0 && air < 1 ? math.sin(air * math.pi) * .6 : 0.0;
    return (
      dx: 0,
      dy: -.32 * height,
      scaleX: 1 + .14 * squash - .06 * stretch,
      scaleY: 1 - .16 * squash + .08 * stretch,
      angle: 0,
      trail: .5 * stretch,
      ring: t > .78 ? _span(t, .78, 1) : 0,
      flash: 0,
    );
  }

  /// A kick at progress [t]: wind back, lunge forward (lean + push) with an
  /// impact flash, then return.
  static SpecimenFrame kickAt(double t) {
    final back = math.sin(_span(t, 0, .25) * math.pi / 2);
    final lunge = Curves.easeOutCubic.transform(_span(t, .2, .45));
    final settle = Curves.easeInOut.transform(_span(t, .5, 1));
    final push = lunge * (1 - settle);
    return (
      dx: -.06 * back * (1 - lunge) + .16 * push,
      dy: 0,
      scaleX: 1 + .06 * push,
      scaleY: 1 - .04 * push,
      angle: -.08 * back * (1 - lunge) + .24 * push,
      trail: .6 * push * (1 - _span(t, .45, .7)),
      ring: 0,
      flash: math.sin(_span(t, .35, .65) * math.pi),
    );
  }

  static SpecimenFrame move(SpecimenMove move, double t) => switch (move) {
    SpecimenMove.jump => jumpAt(t),
    SpecimenMove.kick => kickAt(t),
  };

  static Duration durationOf(SpecimenMove move) => switch (move) {
    SpecimenMove.jump => jumpDuration,
    SpecimenMove.kick => kickDuration,
  };
}

/// Hands out the next tap move: jump, kick, jump, kick, ...
class TapMoves {
  SpecimenMove _next = SpecimenMove.jump;

  SpecimenMove take() {
    final move = _next;
    _next = move == SpecimenMove.jump ? SpecimenMove.kick : SpecimenMove.jump;
    return move;
  }
}
