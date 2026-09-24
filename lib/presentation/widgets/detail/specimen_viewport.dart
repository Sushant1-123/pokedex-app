import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_tokens.dart';
import '../../providers/pokemon_detail_provider.dart';
import '../grid_background.dart';
import '../panel.dart';
import '../pokemon_card.dart';
import '../pokemon_image.dart';
import 'specimen_choreography.dart';

/// Holographic specimen viewport on the detail screen.
///
/// After the Hero flight from the card lands, the Pokemon dashes in from the
/// left with a glowing trail, jumps and lands with squash and stretch and a
/// floor ring, lunges into a kick with an impact flash, then floats with a
/// matching floor shadow. Taps alternate a jump and a kick. With a mouse,
/// hovering the artwork makes it lean toward the cursor and hop once while
/// it keeps floating. Everything glows in the Pokemon's own colour
/// ([glow]). With "reduce motion" on, all of that becomes a single fade.
class SpecimenViewport extends ConsumerStatefulWidget {
  final int pokemonId;
  final String? heroTag;
  final String? imageUrl;
  final String? animatedSpriteUrl;
  final Color glow;

  const SpecimenViewport({
    super.key,
    required this.pokemonId,
    required this.heroTag,
    required this.imageUrl,
    required this.glow,
    this.animatedSpriteUrl,
  });

  static const floatPeriod = Duration(milliseconds: 2600);
  static const fadeDuration = Duration(milliseconds: 300);

  @override
  ConsumerState<SpecimenViewport> createState() => _SpecimenViewportState();
}

class _SpecimenViewportState extends ConsumerState<SpecimenViewport>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: SpecimenChoreography.entranceDuration,
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: SpecimenViewport.floatPeriod,
  );
  late final AnimationController _move = AnimationController(vsync: this);

  /// -1 (leaning left) .. 1 (leaning right) toward the hovering cursor.
  late final AnimationController _lean = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _hoverJump = AnimationController(
    vsync: this,
    duration: AppMotion.viewportHoverJump,
  );
  double? _hoverSide;
  final _moves = TapMoves();
  SpecimenMove _currentMove = SpecimenMove.jump;

  bool _reducedMotion = false;
  Animation<double>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _entrance.duration = SpecimenViewport.fadeDuration;
      _float.stop();
    }
    final route = ModalRoute.of(context)?.animation;
    if (route != _route) {
      _route?.removeStatusListener(_onRouteStatus);
      _route = route;
      // Start the entrance once the Hero flight has landed.
      if (route == null || route.isCompleted) {
        _startEntrance();
      } else {
        route.addStatusListener(_onRouteStatus);
      }
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startEntrance();
  }

  void _startEntrance() {
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    _entrance.forward().whenComplete(() {
      if (mounted && !_reducedMotion) _float.repeat();
    });
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRouteStatus);
    _entrance.dispose();
    _float.dispose();
    _move.dispose();
    _lean.dispose();
    _hoverJump.dispose();
    super.dispose();
  }

  /// Tracks the cursor over the viewport; [art] is the artwork's resting
  /// box, so the reaction doesn't flicker while the Pokemon moves.
  void _onPointer(Offset? position, Rect art) {
    final side = position == null ? null : hoverSide(position, art);
    if (side == _hoverSide) return;
    final entered = _hoverSide == null;
    _hoverSide = side;
    if (_reducedMotion) return;
    _lean.animateTo(
      side ?? 0,
      duration: AppMotion.viewportLeanDuration,
      curve: Curves.easeOutCubic,
    );
    if (entered && side != null && _entrance.isCompleted) {
      _hoverJump.forward(from: 0);
    }
  }

  void _onTap() {
    if (_reducedMotion || _entrance.isAnimating) return;
    _currentMove = _moves.take();
    _move
      ..duration = SpecimenChoreography.durationOf(_currentMove)
      ..forward(from: 0);
  }

  SpecimenFrame get _frame => _move.isAnimating
      ? SpecimenChoreography.move(_currentMove, _move.value)
      : SpecimenChoreography.entrance(
          _entrance.value,
          reducedMotion: _reducedMotion,
        );

  @override
  Widget build(BuildContext context) {
    final animatedOn = ref.watch(animatedSpriteProvider);
    final spriteUrl = widget.animatedSpriteUrl;
    final showSprite = animatedOn && spriteUrl != null;
    final glow = widget.glow;
    final image = PokemonImage(
      url: showSprite ? spriteUrl : widget.imageUrl,
      accent: glow,
      filterQuality: showSprite ? FilterQuality.none : FilterQuality.medium,
    );
    final heroTag = widget.heroTag;

    return Panel(
      glow: glow,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: BoxDecoration(color: glow, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'HOLOGRAPHIC SPECIMEN TELEMETRY',
                  style: AppTypography.label.copyWith(color: AppColors.cyan),
                ),
              ),
              _AnimatedToggle(
                available: spriteUrl != null,
                active: showSprite,
                onToggle: ref.read(animatedSpriteProvider.notifier).toggle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 1.15,
            child: GridBackground(
              spacing: 22,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final artSize = size.shortestSide * .66;
                  final floorY = size.height / 2 + artSize * .44;
                  final artRect = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: artSize,
                    height: artSize,
                  );
                  return MouseRegion(
                    onHover: (event) =>
                        _onPointer(event.localPosition, artRect),
                    onExit: (_) => _onPointer(null, artRect),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _entrance,
                        _float,
                        _move,
                        _lean,
                        _hoverJump,
                      ]),
                      builder: (context, _) {
                        final frame = _frame;
                        final bob = _reducedMotion
                            ? 0.0
                            : math.sin(_float.value * 2 * math.pi) * .035 +
                                  math.sin(_hoverJump.value * math.pi) *
                                      AppMotion.viewportHoverHop;
                        final lean = _reducedMotion ? 0.0 : _lean.value;
                        Widget posed(Widget child) => Transform.translate(
                          offset: Offset(
                            (frame.dx + lean * AppMotion.viewportLeanShift) *
                                artSize,
                            (frame.dy - bob) * artSize,
                          ),
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..rotateZ(
                                frame.angle + lean * AppMotion.viewportLean,
                              )
                              ..scaleByDouble(frame.scaleX, frame.scaleY, 1, 1),
                            child: SizedBox.square(
                              dimension: artSize,
                              child: child,
                            ),
                          ),
                        );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: _ViewportBackdrop(
                                glow: glow,
                                label: dexNumber(widget.pokemonId),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FloorFxPainter(
                                  glow: glow,
                                  floorY: floorY,
                                  width: artSize,
                                  lift: -frame.dy + bob,
                                  ring: frame.ring,
                                ),
                              ),
                            ),
                            if (frame.trail > 0)
                              for (var k = 3; k >= 1; k--)
                                IgnorePointer(
                                  child: Transform.translate(
                                    offset: Offset(-k * artSize * .14, 0),
                                    child: Opacity(
                                      opacity: (frame.trail * .45 / k).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: posed(
                                        ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            glow,
                                            BlendMode.srcIn,
                                          ),
                                          child: image,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            Opacity(
                              opacity: _reducedMotion ? _entrance.value : 1,
                              child: posed(
                                Semantics(
                                  button: true,
                                  label: 'Play move',
                                  child: GestureDetector(
                                    onTap: _onTap,
                                    child: heroTag == null
                                        ? image
                                        : Hero(tag: heroTag, child: image),
                                  ),
                                ),
                              ),
                            ),
                            if (frame.flash > 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _ImpactFlashPainter(
                                      glow: glow,
                                      strength: frame.flash,
                                      center: Offset(
                                        size.width / 2 +
                                            (frame.dx + .42) * artSize,
                                        size.height / 2,
                                      ),
                                      radius: artSize * .35,
                                    ),
                                  ),
                                ),
                              ),
                            const Positioned.fill(
                              child: IgnorePointer(child: _CornerBrackets()),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which side of [art] the cursor at [position] is on: -1 left, 1 right,
/// or null when it is outside the artwork.
double? hoverSide(Offset position, Rect art) {
  if (!art.contains(position)) return null;
  return position.dx < art.center.dx ? -1 : 1;
}

/// Radial glow in the Pokemon's colour with a large faded dex number
/// behind it.
class _ViewportBackdrop extends StatelessWidget {
  final Color glow;
  final String label;
  const _ViewportBackdrop({required this.glow, required this.label});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: .75,
        colors: [glow.withValues(alpha: .28), glow.withValues(alpha: 0)],
      ),
    ),
    child: Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            label,
            style: AppTypography.watermark.copyWith(
              color: glow.withValues(alpha: .08),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Floor shadow (smaller and fainter the higher the Pokemon is) and the
/// landing ring.
class _FloorFxPainter extends CustomPainter {
  final Color glow;
  final double floorY;
  final double width;
  final double lift;
  final double ring;

  const _FloorFxPainter({
    required this.glow,
    required this.floorY,
    required this.width,
    required this.lift,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, floorY);
    final shrink = (1 - lift * 2).clamp(.4, 1.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: width * .7 * shrink,
        height: width * .09 * shrink,
      ),
      Paint()
        ..color = AppColors.surfaceSunken.withValues(
          alpha: (.7 * shrink).clamp(0.0, 1.0),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .03),
    );
    if (ring > 0 && ring < 1) {
      final fade = 1 - ring;
      final rect = Rect.fromCenter(
        center: center,
        width: width * (.4 + ring * 1.1),
        height: width * (.08 + ring * .2),
      );
      canvas
        ..drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + 3 * fade
            ..color = glow.withValues(alpha: .9 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        )
        ..drawOval(
          rect.deflate(width * .04),
          Paint()..color = glow.withValues(alpha: .18 * fade),
        );
    }
  }

  @override
  bool shouldRepaint(_FloorFxPainter old) =>
      old.glow != glow ||
      old.floorY != floorY ||
      old.width != width ||
      old.lift != lift ||
      old.ring != ring;
}

/// Short impact flash in front of the Pokemon during a kick.
class _ImpactFlashPainter extends CustomPainter {
  final Color glow;
  final double strength;
  final Offset center;
  final double radius;

  const _ImpactFlashPainter({
    required this.glow,
    required this.strength,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius * (.6 + strength * .6);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.textPrimary.withValues(alpha: .9 * strength),
            glow.withValues(alpha: .6 * strength),
            glow.withValues(alpha: 0),
          ],
          stops: const [0, .35, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final spark = Paint()
      ..color = glow.withValues(alpha: strength)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * r * .5, center + dir * r * 1.1, spark);
    }
  }

  @override
  bool shouldRepaint(_ImpactFlashPainter old) =>
      old.glow != glow ||
      old.strength != strength ||
      old.center != center ||
      old.radius != radius;
}

class _AnimatedToggle extends StatelessWidget {
  final bool available;
  final bool active;
  final VoidCallback onToggle;

  const _AnimatedToggle({
    required this.available,
    required this.active,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = !available
        ? AppColors.border
        : active
        ? AppColors.surface
        : AppColors.cyan;
    return Tooltip(
      message: available
          ? (active ? 'Show HD artwork' : 'Show animated sprite')
          : 'No animated sprite',
      child: Material(
        color: active ? AppColors.cyan : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide(
            color: available ? AppColors.cyan : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: available ? onToggle : null,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'ANIMATED',
                  style: AppTypography.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cyan corner brackets framing the viewport, as in the Stitch frame.
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _CornerBracketPainter());
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    const arm = 18.0;
    final paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: .8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final (x, dx) in [(inset, 1.0), (size.width - inset, -1.0)]) {
      for (final (y, dy) in [(inset, 1.0), (size.height - inset, -1.0)]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y + dy * arm)
            ..lineTo(x, y)
            ..lineTo(x + dx * arm, y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => false;
}
