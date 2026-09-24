import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/pokemon_detail_provider.dart';
import '../providers/section_providers.dart';
import '../widgets/detail/detail_sections.dart';
import '../widgets/detail/specimen_viewport.dart';
import '../widgets/error_view.dart';
import '../widgets/field_shell.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/panel.dart';
import '../widgets/pokemon_card.dart';

/// Specimen telemetry for one Pokemon: stacked on mobile, two columns
/// (flex 5 / 7) on tablet and desktop, as in the Stitch frames.
class PokemonDetailScreen extends ConsumerWidget {
  final int pokemonId;
  final String? heroTag;

  /// Artwork already known from the card, so the Hero lands on a real image
  /// while the record loads.
  final String? initialImageUrl;

  const PokemonDetailScreen({
    super.key,
    required this.pokemonId,
    this.heroTag,
    this.initialImageUrl,
  });

  void _open(BuildContext context, int id) =>
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PokemonDetailScreen(pokemonId: id)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pokemonDetailProvider(pokemonId);
    final result = ref.watch(provider);
    final retry = ref.read(provider.notifier).load;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final padding = Breakpoints.pagePaddingFor(
      MediaQuery.sizeOf(context).width,
    );

    final neighbours = switch (result) {
      Success(:final data) => data.neighbours,
      _ => (previous: null, next: null),
    };
    final breadcrumbs = _Breadcrumbs(
      pokemonId: pokemonId,
      name: switch (result) {
        Success(:final data) => data.detail.name,
        _ => null,
      },
      neighbours: neighbours,
      onOpen: (id) => _open(context, id),
    );

    final body = switch (result) {
      Failure(:final message) => ErrorView(
        title: 'Specimen Sector Checksum Mismatch',
        message: message,
        onRetry: retry,
      ),
      // Same slots as the loaded layout, so the viewport (and its Hero and
      // entrance animation) keeps its state when the record arrives.
      Loading() => _Layout(
        wide: wide,
        left: [
          const Panel(child: SectionSkeleton()),
          SpecimenViewport(
            pokemonId: pokemonId,
            heroTag: heroTag,
            imageUrl: initialImageUrl ?? pokemonArtworkUrl(pokemonId),
            glow: AppColors.cyan,
          ),
          const Panel(child: SectionSkeleton(lines: 2)),
        ],
        right: const [
          Panel(child: SectionSkeleton(lines: 6)),
          Panel(child: SectionSkeleton(lines: 2)),
        ],
      ),
      Success(:final data) => _Layout(
        wide: wide,
        left: [
          IdentityPanel(detail: data.detail, species: data.species),
          SpecimenViewport(
            pokemonId: pokemonId,
            heroTag: heroTag,
            imageUrl: data.detail.imageUrl,
            animatedSpriteUrl: data.detail.animatedSpriteUrl,
            glow: pokemonGlowColor(switch (data.species) {
              Success(:final data) => data.color,
              _ => null,
            }, data.detail.types),
          ),
          PhysicalMetricsPanel(
            detail: data.detail,
            species: data.species,
            onRetry: retry,
          ),
          if (wide)
            EvolutionPanel(
              evolution: data.evolution,
              currentSpeciesId: data.detail.speciesId,
              onOpen: (id) => _open(context, id),
              onRetry: retry,
            ),
        ],
        right: [
          BaseStatsPanel(detail: data.detail),
          AbilitiesPanel(detail: data.detail),
          DefensesPanel(defenses: data.defenses, onRetry: retry),
          if (!wide)
            EvolutionPanel(
              evolution: data.evolution,
              currentSpeciesId: data.detail.speciesId,
              onOpen: (id) => _open(context, id),
              onRetry: retry,
            ),
          FieldNotesPanel(species: data.species, onRetry: retry),
        ],
      ),
    };

    return FieldShell(
      active: AppDestination.specimenIndex,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            breadcrumbs,
            const SizedBox(height: AppSpacing.xl),
            body,
          ],
        ),
      ),
    );
  }
}

class _Layout extends StatelessWidget {
  final bool wide;
  final List<Widget> left;
  final List<Widget> right;

  const _Layout({required this.wide, required this.left, required this.right});

  static Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.xxl),
        children[i],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _column(left)),
            const SizedBox(width: AppSpacing.xxl),
            Expanded(flex: 7, child: _column(right)),
          ],
        )
      : _column([...left, ...right]);
}

/// Back button, "DIRECTORY / #0006 CHARIZARD" and prev/next specimens.
class _Breadcrumbs extends StatelessWidget {
  final int pokemonId;
  final String? name;
  final DexNeighbours neighbours;
  final ValueChanged<int> onOpen;

  const _Breadcrumbs({
    required this.pokemonId,
    required this.name,
    required this.neighbours,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Directory'),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'DIRECTORY / '),
                  TextSpan(
                    text: [
                      dexNumber(pokemonId),
                      if (name case final String name) name.toUpperCase(),
                    ].join(' '),
                    style: const TextStyle(color: AppColors.cyan),
                  ),
                ],
              ),
              style: AppTypography.caption,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (neighbours.previous case final PokemonIndexEntry previous)
              _NeighbourLink(
                entry: previous,
                forward: false,
                onTap: () => onOpen(previous.id),
              ),
            if (neighbours.next case final PokemonIndexEntry next)
              _NeighbourLink(
                entry: next,
                forward: true,
                onTap: () => onOpen(next.id),
              ),
            const _CompareButton(),
          ],
        ),
      ],
    ),
  );
}

class _NeighbourLink extends StatelessWidget {
  final PokemonIndexEntry entry;
  final bool forward;
  final VoidCallback onTap;

  const _NeighbourLink({
    required this.entry,
    required this.forward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '${dexNumber(entry.id)} ${titleCase(entry.name)}',
      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
    );
    final icon = Icon(
      forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      size: 16,
      color: AppColors.textSecondary,
    );
    return Tooltip(
      message: forward ? 'Next specimen' : 'Previous specimen',
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: forward ? [label, icon] : [icon, label],
        ),
      ),
    );
  }
}

/// Adds this Pokemon to Compare Lab and opens it.
class _CompareButton extends ConsumerWidget {
  const _CompareButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = context
        .findAncestorWidgetOfExactType<PokemonDetailScreen>()!;
    return FilledButton.icon(
      onPressed: () {
        ref.read(compareProvider.notifier).add(screen.pokemonId);
        navigateToDestination(context, ref, AppDestination.compare);
      },
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.crimson,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
      label: const Text('Compare'),
    );
  }
}
