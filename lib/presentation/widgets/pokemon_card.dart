import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';
import '../../data/models/pokemon_summary.dart';
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

/// Directory card: dex number, name, glowing type pills, artwork on the
/// coordinate grid, and HP + best-stat bars in the footer.
///
/// It fades/slides in (staggered by [index]) when a page loads, lifts with
/// a glow on hover while the Pokemon hops, and scales down when pressed.
/// With reduce motion only the press feedback remains.
class PokemonCard extends StatefulWidget {
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
  State<PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<PokemonCard>
    with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: AppMotion.hop,
  );
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
    _hop.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    setState(() => _hovered = hovered);
    if (hovered && !_reducedMotion) _hop.forward(from: 0);
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
        _hovered && !_reducedMotion ? -AppMotion.cardLift : 0,
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
                  child: _Artwork(pokemon: pokemon, accent: accent, hop: _hop),
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
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
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
/// with a faint dex-number watermark. [hop] makes it jump on hover.
class _Artwork extends StatelessWidget {
  final PokemonSummary pokemon;
  final Color accent;
  final Animation<double> hop;

  const _Artwork({
    required this.pokemon,
    required this.accent,
    required this.hop,
  });

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
        child: AnimatedBuilder(
          animation: hop,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              -math.sin(hop.value * math.pi) * AppMotion.cardHop,
            ),
            child: child,
          ),
          child: Hero(
            tag: 'pokemon-image-${pokemon.id}',
            child: PokemonImage(url: pokemon.imageUrl, accent: accent),
          ),
        ),
      ),
    ],
  );
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
