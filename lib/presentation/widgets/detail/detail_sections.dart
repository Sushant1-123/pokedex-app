import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/design_tokens.dart';
import '../../../core/result.dart';
import '../../../data/models/evolution_chain.dart';
import '../../../data/models/pokemon_detail.dart';
import '../../../data/models/pokemon_species.dart';
import '../../../data/models/type_defenses.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../error_view.dart';
import '../loading_skeleton.dart';
import '../panel.dart';
import '../pokemon_card.dart';
import '../pokemon_image.dart';
import '../stat_bar.dart';
import '../type_badge.dart';

/// Renders a section's [Result]: its skeleton while loading, a compact error
/// with retry on failure, or [builder] with the data.
class SectionResult<T> extends StatelessWidget {
  final Result<T> result;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final int skeletonLines;

  const SectionResult({
    super.key,
    required this.result,
    required this.onRetry,
    required this.builder,
    this.skeletonLines = 3,
  });

  @override
  Widget build(BuildContext context) => switch (result) {
    Loading() => SectionSkeleton(lines: skeletonLines),
    Failure(:final message) => SectionError(message: message, onRetry: onRetry),
    Success(:final data) => builder(data),
  };
}

/// Number, genus, generation, name, tags and animated type badges.
class IdentityPanel extends StatelessWidget {
  final PokemonDetail detail;
  final Result<PokemonSpecies> species;

  const IdentityPanel({super.key, required this.detail, required this.species});

  @override
  Widget build(BuildContext context) {
    final data = switch (species) {
      Success(:final data) => data,
      _ => null,
    };
    final tags = [
      if (data?.isLegendary ?? false) ('LEGENDARY', AppColors.warning),
      if (data?.isMythical ?? false) ('MYTHICAL', AppColors.warning),
      if (!detail.isBaseSpecies) ('ALTERNATE FORM', AppColors.cyan),
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(text: dexNumber(detail.id), color: AppColors.textSecondary),
              if (data?.genus case final String genus)
                Text(
                  '● ${genus.toUpperCase()}',
                  style: AppTypography.label.copyWith(color: AppColors.cyan),
                ),
              if (data?.generation case final String generation)
                Text('GEN $generation', style: AppTypography.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(titleCase(detail.name), style: AppTypography.display),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (text, color) in tags)
                  _Chip(text: text, color: color),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < detail.types.length; i++)
                TypeBadge(type: detail.types[i], index: i),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs + 1,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      border: Border.all(color: color.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Text(text, style: AppTypography.label.copyWith(color: color)),
  );
}

/// Height, weight, gender ratio and base experience (XP yield).
class PhysicalMetricsPanel extends StatelessWidget {
  final PokemonDetail detail;
  final Result<PokemonSpecies> species;
  final VoidCallback onRetry;

  const PhysicalMetricsPanel({
    super.key,
    required this.detail,
    required this.species,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final totalInches = (detail.heightM / .0254).round();
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).toString().padLeft(2, '0');
    final pounds = (detail.weightKg * 2.20462).toStringAsFixed(1);
    final growth = switch (species) {
      Success(:final data) => data.growthRate,
      _ => null,
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'PHYSICAL METRIC TELEMETRY'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 440 ? 4 : 2;
              final tileWidth =
                  (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final tile in [
                    _MetricTile(
                      icon: Icons.height_rounded,
                      label: 'HEIGHT',
                      value: '${detail.heightM} m',
                      caption: "$feet'$inches\"",
                    ),
                    _MetricTile(
                      icon: Icons.scale_rounded,
                      label: 'WEIGHT',
                      value: '${detail.weightKg} kg',
                      caption: '$pounds lbs',
                    ),
                    _GenderTile(species: species, onRetry: onRetry),
                    _MetricTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'EXP YIELD',
                      value: detail.baseExperience == null
                          ? '—'
                          : '${detail.baseExperience} XP',
                      valueColor: AppColors.warning,
                      caption: growth == null ? null : titleCase(growth),
                    ),
                  ])
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color valueColor;
  final Widget? valueWidget;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor = AppColors.textPrimary,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AppTypography.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        valueWidget ??
            Text(
              value,
              style: AppTypography.metric.copyWith(color: valueColor),
            ),
        if (caption case final String caption) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(caption, style: AppTypography.bodySmall),
        ],
      ],
    ),
  );
}

class _GenderTile extends StatelessWidget {
  final Result<PokemonSpecies> species;
  final VoidCallback onRetry;
  const _GenderTile({required this.species, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final value = switch (species) {
      Loading() => const SkeletonShimmer(
        child: SkeletonBlock(height: 18, width: 70),
      ),
      Failure() => IconButton(
        onPressed: onRetry,
        tooltip: 'Retry',
        icon: const Icon(Icons.refresh_rounded, color: AppColors.crimson),
      ),
      Success(:final data) => switch (data.genderRatio) {
        Genderless() => Text(
          'Genderless',
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Gendered(:final malePercent, :final femalePercent) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GenderShare(
              percent: _percent(malePercent),
              icon: Icons.male_rounded,
              color: AppColors.cyan,
              label: 'male',
            ),
            _GenderShare(
              percent: _percent(femalePercent),
              icon: Icons.female_rounded,
              color: AppColors.crimson,
              label: 'female',
            ),
          ],
        ),
      },
    };
    return _MetricTile(
      icon: Icons.wc_rounded,
      label: 'GENDER RATIO',
      value: '',
      valueWidget: value,
    );
  }

  static String _percent(double value) =>
      '${value == value.roundToDouble() ? value.toInt() : value}%';
}

/// "87.5% ♂" with the symbol drawn as an icon: the bundled font has no
/// gender glyphs, and a fallback font would be fetched at runtime on web.
class _GenderShare extends StatelessWidget {
  final String percent;
  final IconData icon;
  final Color color;
  final String label;

  const _GenderShare({
    required this.percent,
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$percent $label',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(percent, style: AppTypography.titleSmall.copyWith(color: color)),
          const SizedBox(width: AppSpacing.xxs),
          Icon(icon, size: 16, color: color),
        ],
      ),
    ),
  );
}

/// Base stats with the total (BST), each bar coloured by value.
class BaseStatsPanel extends StatelessWidget {
  final PokemonDetail detail;
  const BaseStatsPanel({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'BASE STAT CALIBRATION',
            icon: Icons.bar_chart_rounded,
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${detail.baseStatTotal}',
                      style: AppTypography.metric.copyWith(
                        color: AppColors.cyan,
                      ),
                    ),
                    const TextSpan(text: '  TOTAL BST'),
                  ],
                ),
                style: AppTypography.caption,
              ),
            ),
          ),
          for (final stat in detail.stats)
            StatBar(label: statLabel(stat.name), value: stat.base),
        ],
      ),
    );
  }
}

/// Abilities, with hidden abilities marked.
class AbilitiesPanel extends StatelessWidget {
  final PokemonDetail detail;
  const AbilitiesPanel({super.key, required this.detail});

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'INHERENT CAPABILITIES',
          icon: Icons.auto_awesome_outlined,
          trailing: Text(
            '${detail.abilities.length} TRAITS',
            style: AppTypography.caption,
          ),
        ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final ability in detail.abilities)
              _AbilityChip(ability: ability),
          ],
        ),
      ],
    ),
  );
}

/// Weaknesses, resistances and immunities from /type damage relations.
class DefensesPanel extends StatelessWidget {
  final Result<TypeDefenses> defenses;
  final VoidCallback onRetry;
  const DefensesPanel({
    super.key,
    required this.defenses,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'DEFENSIVE SPECTRAL MATRIX',
          icon: Icons.shield_outlined,
          trailing: Text('DAMAGE FACTORS', style: AppTypography.caption),
        ),
        SectionResult(
          result: defenses,
          onRetry: onRetry,
          builder: (matrix) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CRITICAL VULNERABILITIES',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MatchupWrap(
                empty: 'No weaknesses',
                children: [
                  for (final m in matrix.weaknesses)
                    _MatchupChip(
                      type: m.type,
                      factor: formatMultiplier(m.multiplier),
                      color: AppColors.crimson,
                      strong: m.multiplier >= 4,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'NATURAL RESISTANCES & IMMUNITIES',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MatchupWrap(
                empty: 'No resistances',
                children: [
                  for (final type in matrix.immunities)
                    _MatchupChip(
                      type: type,
                      factor: '0× (IMMUNE)',
                      color: AppColors.cyan,
                      strong: true,
                    ),
                  for (final m in matrix.resistances)
                    _MatchupChip(
                      type: m.type,
                      factor: formatMultiplier(m.multiplier),
                      color: AppColors.success,
                      strong: false,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 4.0 -> "4×", 0.25 -> "0.25×".
String formatMultiplier(double value) =>
    '${value == value.roundToDouble() ? value.toInt() : value}×';

class _MatchupWrap extends StatelessWidget {
  final String empty;
  final List<Widget> children;
  const _MatchupWrap({required this.empty, required this.children});

  @override
  Widget build(BuildContext context) => children.isEmpty
      ? Text(empty, style: AppTypography.bodySmall)
      : Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children,
        );
}

class _MatchupChip extends StatelessWidget {
  final String type;
  final String factor;
  final Color color;
  final bool strong;

  const _MatchupChip({
    required this.type,
    required this.factor,
    required this.color,
    required this.strong,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: AppSpacing.xs + 2,
    ),
    decoration: BoxDecoration(
      color: strong ? color.withValues(alpha: .14) : AppColors.surface,
      border: Border.all(
        color: strong ? color.withValues(alpha: .7) : AppColors.border,
      ),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          type.toUpperCase(),
          style: AppTypography.label.copyWith(color: colorForType(type)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(factor, style: AppTypography.numeric.copyWith(color: color)),
      ],
    ),
  );
}

/// Evolution stages as tappable cards. Branching chains (e.g. Eevee) show
/// every branch of a stage side by side; each card names its trigger.
class EvolutionPanel extends StatelessWidget {
  final Result<EvolutionChain> evolution;
  final int currentSpeciesId;
  final ValueChanged<int> onOpen;
  final VoidCallback onRetry;

  /// Whether the highlighted stage opens too (Evolution Engine), not only
  /// the others (the detail screen, where it is the open page).
  final bool linkCurrent;

  const EvolutionPanel({
    super.key,
    required this.evolution,
    required this.currentSpeciesId,
    required this.onOpen,
    required this.onRetry,
    this.linkCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final stages = switch (evolution) {
      Success(:final data) => data.stages,
      _ => const <List<EvolutionStage>>[],
    };
    final currentDepth = stages.indexWhere(
      (stage) => stage.any((s) => s.speciesId == currentSpeciesId),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'EVOLUTION SEQUENCE',
            icon: Icons.account_tree_outlined,
            trailing: stages.isEmpty || currentDepth < 0
                ? null
                : _Chip(
                    text: 'STAGE ${currentDepth + 1}/${stages.length}',
                    color: AppColors.success,
                  ),
          ),
          SectionResult(
            result: evolution,
            onRetry: onRetry,
            builder: (chain) => chain.isSingleStage
                ? Row(
                    children: [
                      _StageCard(
                        stage: chain.root,
                        current: true,
                        linkCurrent: linkCurrent,
                        onOpen: onOpen,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      const Expanded(
                        child: Text(
                          'This species does not evolve.',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var depth = 0; depth < stages.length; depth++) ...[
                        if (depth > 0)
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.cyan,
                            size: 18,
                          ),
                        for (final stage in stages[depth])
                          _StageCard(
                            stage: stage,
                            current: stage.speciesId == currentSpeciesId,
                            linkCurrent: linkCurrent,
                            onOpen: onOpen,
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Lv. 16", "Thunder Stone", "Trade", ...
String describeTrigger(EvolutionTrigger? trigger) => switch (trigger) {
  null => 'Base stage',
  LevelUp(:final level) => 'Lv. $level',
  UseItem(:final item) => titleCase(item),
  Trade(heldItem: null) => 'Trade',
  Trade(heldItem: final String item) => 'Trade · ${titleCase(item)}',
  Friendship(timeOfDay: null) => 'Friendship',
  Friendship(timeOfDay: final String time) => 'Friendship · ${titleCase(time)}',
  OtherMethod(:final trigger) => titleCase(trigger),
};

class _StageCard extends StatelessWidget {
  final EvolutionStage stage;
  final bool current;
  final bool linkCurrent;
  final ValueChanged<int> onOpen;

  const _StageCard({
    required this.stage,
    required this.current,
    required this.onOpen,
    required this.linkCurrent,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: !current || linkCurrent,
    label: '${titleCase(stage.name)}, ${describeTrigger(stage.trigger)}',
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
          color: current ? AppColors.crimson : AppColors.border,
          width: current ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: current && !linkCurrent ? null : () => onOpen(stage.speciesId),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                Text(
                  dexNumber(stage.speciesId),
                  style: AppTypography.caption.copyWith(
                    color: current ? AppColors.crimson : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox.square(
                  dimension: 56,
                  child: PokemonImage(
                    url: pokemonArtworkUrl(stage.speciesId),
                    accent: AppColors.cyan,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  titleCase(stage.name),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  current ? 'CURRENT' : describeTrigger(stage.trigger),
                  style: AppTypography.caption.copyWith(
                    color: current ? AppColors.crimson : AppColors.cyan,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// English Pokedex entry from /pokemon-species.
class FieldNotesPanel extends StatelessWidget {
  final Result<PokemonSpecies> species;
  final VoidCallback onRetry;
  const FieldNotesPanel({
    super.key,
    required this.species,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'FIELD NOTES', icon: Icons.notes_rounded),
        SectionResult(
          result: species,
          onRetry: onRetry,
          skeletonLines: 2,
          builder: (data) => Text(
            data.flavorText ?? 'No field notes recorded for this specimen.',
            style: AppTypography.body,
          ),
        ),
      ],
    ),
  );
}

/// An ability card; tapping it opens the ability in Ability Codex.
class _AbilityChip extends ConsumerWidget {
  final PokemonAbility ability;
  const _AbilityChip({required this.ability});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      side: BorderSide(
        color: ability.isHidden
            ? AppColors.crimson.withValues(alpha: .5)
            : AppColors.border,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () {
        ref.read(abilityCodexProvider.notifier).select(ability.name);
        Navigator.of(context).pushNamed(AppDestination.abilities.path);
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                titleCase(ability.name),
                style: AppTypography.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _Chip(
              text: ability.isHidden ? 'HIDDEN' : 'STANDARD',
              color: ability.isHidden ? AppColors.crimson : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}
