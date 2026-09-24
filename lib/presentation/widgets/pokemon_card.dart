import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/core_providers.dart';
import 'grid_background.dart';
import 'pokemon_image.dart';
import 'saved_record_button.dart';
import 'stat_bar.dart';
import 'type_badge.dart';

/// Formats a dex number the way the Stitch cards do: #0006.
String dexNumber(int id) => '#${id.toString().padLeft(4, '0')}';

String titleCase(String value) => value
    .split('-')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Card height for a grid cell [width] wide: fixed chrome plus artwork.
double pokemonCardExtent(double width) => 190 + width * .58;

/// Delay before the card at grid [index] starts its entrance: a short
/// stagger that stops growing after [AppMotion.staggerMaxSteps] cards.
Duration staggerDelay(int index) =>
    AppMotion.staggerStep * math.min(index, AppMotion.staggerMaxSteps);

/// Which side of a [width]-wide box a pointer at [localX] is on: -1 for
/// the left half, 1 for the right.
double entrySide(double localX, double width) => localX < width / 2 ? -1 : 1;

/// Where the card artwork is drawn relative to its resting place.
@immutable
class CardArtPose {
  /// Horizontal offset as a fraction of the artwork width.
  final double dx;

  /// Vertical offset in pixels (negative is up).
  final double dy;

  /// Landing squash: wider and shorter by this fraction.
  final double squash;

  /// Motion-trail strength, 0..1, with ghosts drawn toward [trailSide].
  final double trail;
  final double trailSide;

  const CardArtPose({
    this.dx = 0,
    this.dy = 0,
    this.squash = 0,
    this.trail = 0,
    this.trailSide = 0,
  });

  static const rest = CardArtPose();

  bool get atRest => dx == 0 && dy == 0 && squash == 0 && trail == 0;

  /// Hover entrance at progress [t] (0..1) for a cursor that came in from
  /// [side]: slide in from that side with a fading trail, then a hop that
  /// lands with a squash.
  factory CardArtPose.entrance(double t, double side) {
    const slideEnd = .55;
    const landAt = .7;
    if (t < slideEnd) {
      final p = t / slideEnd;
      return CardArtPose(
        dx:
            side *
            AppMotion.cardSlideFrom *
            (1 - Curves.easeOutCubic.transform(p)),
        trail: 1 - p,
        trailSide: side,
      );
    }
    final p = (t - slideEnd) / (1 - slideEnd);
    if (p < landAt) {
      return CardArtPose(
        dy: -math.sin(math.pi * p / landAt) * AppMotion.cardHop,
      );
    }
    return CardArtPose(
      squash:
          math.sin(math.pi * (p - landAt) / (1 - landAt)) *
          AppMotion.cardSquash,
    );
  }

  /// This pose plus the idle bob at [phase] (0..1).
  CardArtPose bobbed(double phase) => CardArtPose(
    dx: dx,
    dy: dy - math.sin(2 * math.pi * phase) * AppMotion.cardBob,
    squash: squash,
    trail: trail,
    trailSide: trailSide,
  );

  /// This pose eased back to rest at progress [u] (0..1), with a small
  /// slide toward the exit [side] on the way.
  CardArtPose settle(double u, double side) {
    final keep = 1 - Curves.easeOutCubic.transform(u);
    return CardArtPose(
      dx: dx * keep + side * AppMotion.cardExitSlide * math.sin(math.pi * u),
      dy: dy * keep,
      squash: squash * keep,
    );
  }
}

/// Directory card: dex number, name, glowing type pills, artwork on the
/// coordinate grid, and HP + best-stat bars in the footer.
///
/// It fades/slides in (staggered by [index]) when a page loads and scales
/// down when pressed. With a mouse, hovering lifts it with a glow while the
/// artwork slides in from the side the cursor entered, trailing its colour,
/// hops and bobs; leaving settles it back. Only the hovered card animates.
/// With reduce motion only the lift, glow and press feedback remain.
class PokemonCard extends ConsumerStatefulWidget {
  final PokemonSummary pokemon;
  final VoidCallback onTap;
  final int index;

  const PokemonCard({
    super.key,
    required this.pokemon,
    required this.onTap,
    this.index = 0,
  });

  @override
  ConsumerState<PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends ConsumerState<PokemonCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.cardEntrance,
  );
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: AppMotion.cardBobPeriod,
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: AppMotion.cardSettle,
  );
  late final Listenable _art = Listenable.merge([_enter, _bob, _settle]);
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: staggerDelay(widget.index) + AppMotion.staggerItem,
  );
  // The controller spans delay + item time; the Interval holds the card
  // hidden for its stagger delay without needing a timer.
  late final Animation<double> _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: Interval(
      staggerDelay(widget.index).inMicroseconds /
          _entrance.duration!.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _hovered = false;
  bool _pressed = false;
  bool _reducedMotion = false;
  double _enterSide = -1;
  double _exitSide = 1;
  CardArtPose _leftFrom = CardArtPose.rest;
  Color? _trailColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _entrance.value = 1;
    } else if (_entrance.isDismissed) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _bob.dispose();
    _settle.dispose();
    _entrance.dispose();
    super.dispose();
  }

  double _sideOf(Offset local) => entrySide(local.dx, context.size!.width);

  CardArtPose get _pose {
    if (_reducedMotion) return CardArtPose.rest;
    if (_hovered) {
      return CardArtPose.entrance(_enter.value, _enterSide).bobbed(_bob.value);
    }
    return _settle.isAnimating
        ? _leftFrom.settle(_settle.value, _exitSide)
        : CardArtPose.rest;
  }

  void _onEnter(PointerEnterEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    setState(() => _hovered = true);
    if (_reducedMotion) return;
    _enterSide = _sideOf(event.localPosition);
    _trailColor = pokemonGlowColor(
      ref.read(pokemonRepositoryProvider).cachedSpeciesColor(widget.pokemon.id),
      widget.pokemon.types,
    );
    _settle.value = 0;
    _bob.value = 0;
    _enter.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && _hovered && _enter.isCompleted) _bob.repeat();
    });
  }

  void _onExit(PointerExitEvent event) {
    if (!_hovered) return;
    final from = _pose;
    setState(() => _hovered = false);
    if (_reducedMotion) return;
    _enter.stop();
    _bob.stop();
    _leftFrom = from;
    _exitSide = _sideOf(event.localPosition);
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pokemon = widget.pokemon;
    final accent = pokemon.types.isNotEmpty
        ? colorForType(pokemon.types.first)
        : AppColors.textMuted;
    final entrance = _entranceCurve;

    final card = AnimatedContainer(
      duration: AppMotion.hover,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        _hovered ? -AppMotion.cardLift : 0,
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: _hovered ? accent.withValues(alpha: .55) : AppColors.border,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.container, accent.withValues(alpha: .1)],
          stops: const [.6, 1],
        ),
        boxShadow: [
          if (_hovered)
            BoxShadow(
              color: accent.withValues(alpha: .28),
              blurRadius: 28,
              spreadRadius: -6,
            ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          hoverColor: accent.withValues(alpha: .04),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dexNumber(pokemon.id),
                        style: AppTypography.numeric.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    SavedRecordButton(pokemon: pokemon),
                  ],
                ),
                Text(
                  titleCase(pokemon.name),
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final type in pokemon.types) TypePill(type: type),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _art,
                    builder: (context, _) => CardArtwork(
                      pokemon: pokemon,
                      accent: accent,
                      trailColor: _trailColor ?? accent,
                      pose: _pose,
                    ),
                  ),
                ),
                if (pokemon.stats.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _StatFooter(pokemon: pokemon),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${titleCase(pokemon.name)}, ${dexNumber(pokemon.id)}',
      child: FadeTransition(
        opacity: entrance,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .06),
            end: Offset.zero,
          ).animate(entrance),
          child: MouseRegion(
            onEnter: _onEnter,
            onExit: _onExit,
            child: AnimatedScale(
              scale: _pressed ? AppMotion.cardPressScale : 1,
              duration: AppMotion.press,
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// Artwork on the tinted coordinate grid, popping out above its top edge,
/// with a faint dex-number watermark, drawn at [pose]. While the pose is
/// away from rest the artwork is clipped to its box sideways, and a
/// motion trail in [trailColor] follows it.
class CardArtwork extends StatelessWidget {
  final PokemonSummary pokemon;
  final Color accent;
  final Color trailColor;
  final CardArtPose pose;

  const CardArtwork({
    super.key,
    required this.pokemon,
    required this.accent,
    required this.trailColor,
    required this.pose,
  });

  Widget _posed(Widget child, {double shift = 0}) => FractionalTranslation(
    translation: Offset(pose.dx + shift, 0),
    child: Transform.translate(
      offset: Offset(0, pose.dy),
      child: Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleX: 1 + pose.squash,
        scaleY: 1 - pose.squash,
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        top: AppMotion.artworkOverlap,
        child: GridBackground(
          tint: accent,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  dexNumber(pokemon.id),
                  style: AppTypography.watermark.copyWith(
                    color: accent.withValues(alpha: .07),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        bottom: AppSpacing.sm,
        child: ClipRect(
          clipper: const _SideClipper(),
          clipBehavior: pose.atRest ? Clip.none : Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pose.trail > 0)
                      for (var k = 3; k >= 1; k--)
                        Opacity(
                          opacity: (pose.trail * .5 / k).clamp(0.0, 1.0),
                          child: _posed(
                            shift: pose.trailSide * k * AppMotion.cardTrailGap,
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                trailColor,
                                BlendMode.srcIn,
                              ),
                              child: PokemonImage(
                                url: pokemon.imageUrl,
                                accent: trailColor,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              _posed(
                Hero(
                  tag: 'pokemon-image-${pokemon.id}',
                  child: PokemonImage(url: pokemon.imageUrl, accent: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Clips sideways only, so the artwork can still pop out above its box.
class _SideClipper extends CustomClipper<Rect> {
  const _SideClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height, size.width, size.height * 2);

  @override
  bool shouldReclip(_SideClipper oldClipper) => false;
}

/// "HP BASE 078 / 255" plus the Pokemon's best other stat.
class _StatFooter extends StatelessWidget {
  final PokemonSummary pokemon;
  const _StatFooter({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final hp = pokemon.stats.where((s) => s.name == 'hp').firstOrNull;
    final others = pokemon.stats.where((s) => s.name != 'hp').toList()
      ..sort((a, b) => b.base.compareTo(a.base));
    final best = others.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hp != null)
          MiniStatBar(
            label: 'HP BASE',
            value: '${hp.base.toString().padLeft(3, '0')} / 255',
            fraction: hp.base / 255,
            color: AppColors.crimson,
          ),
        if (best != null) ...[
          const SizedBox(height: AppSpacing.sm),
          MiniStatBar(
            label: statLabel(best.name),
            value: best.base.toString().padLeft(3, '0'),
            fraction: best.base / 255,
            color: AppColors.cyan,
          ),
        ],
      ],
    );
  }
}
