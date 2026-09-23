import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/design_tokens.dart';
import '../../../core/result.dart';
import '../../../data/models/type_chart.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../../widgets/detail/detail_sections.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/panel.dart';
import '../../widgets/section_page.dart';
import '../../widgets/type_badge.dart';

/// The 18x18 attacking-vs-defending type chart, and a per-type panel with
/// its matchups and Pokemon.
class TypeSpectraScreen extends ConsumerWidget {
  const TypeSpectraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(typeSpectraProvider);
    final notifier = ref.read(typeSpectraProvider.notifier);
    return SectionPage(
      destination: AppDestination.types,
      title: 'Type Spectra',
      subtitle:
          'Rows attack, columns defend. Tap any type to see its matchups '
          'and every Pokémon of that type.',
      onRefresh: notifier.load,
      children: [
        switch (state.chart) {
          Loading() => const Panel(child: SectionSkeleton(lines: 10)),
          Failure(:final message) => ErrorView(
            message: message,
            onRetry: notifier.load,
          ),
          Success(data: final chart) => Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'ATTACK ↓ · DEFENSE →',
                  icon: Icons.grid_on_rounded,
                ),
                _TypeChartGrid(chart: chart, onSelect: notifier.select),
                const SizedBox(height: AppSpacing.lg),
                const _Legend(),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final type in chart.types)
                      GestureDetector(
                        onTap: () => notifier.select(type),
                        child: TypePill(type: type),
                      ),
                  ],
                ),
              ],
            ),
          ),
        },
        if ((state.chart, state.selection) case (
          Success(data: final chart),
          final GroupSelection selection,
        ))
          Panel(
            glow: colorForType(selection.name),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: '${selection.name.toUpperCase()} TYPE',
                  icon: Icons.bolt_rounded,
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: notifier.close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                _Matchups(
                  label: 'STRONG AGAINST (2×)',
                  types: chart.strongAgainst(selection.name),
                  empty: 'No super-effective matchups',
                ),
                _Matchups(
                  label: 'WEAK TO (2×)',
                  types: chart.weakTo(selection.name),
                  empty: 'No weaknesses',
                ),
                _Matchups(
                  label: 'IMMUNE TO (0×)',
                  types: chart.immuneTo(selection.name),
                  empty: 'No immunities',
                ),
                const SizedBox(height: AppSpacing.lg),
                PokemonPageGrid(
                  page: selection.page,
                  onPage: (page) => notifier.select(selection.name, page: page),
                  onRetry: () => notifier.select(selection.name),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Grid with a sticky attacker column; the defender columns scroll
/// horizontally on small screens.
class _TypeChartGrid extends StatelessWidget {
  final TypeChart chart;
  final ValueChanged<String> onSelect;
  const _TypeChartGrid({required this.chart, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget label(String type, {bool vertical = false}) => InkWell(
      onTap: () => onSelect(type),
      child: SizedBox(
        width: vertical ? AppSizes.chartCell : AppSizes.chartHeader,
        height: vertical ? AppSizes.chartHeader : AppSizes.chartCell,
        child: Center(
          child: RotatedBox(
            quarterTurns: vertical ? 3 : 0,
            child: Text(
              type.toUpperCase(),
              style: AppTypography.caption.copyWith(color: colorForType(type)),
            ),
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: AppSizes.chartHeader),
            for (final attacker in chart.types) label(attacker),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final defender in chart.types)
                      label(defender, vertical: true),
                  ],
                ),
                for (final attacker in chart.types)
                  Row(
                    children: [
                      for (final defender in chart.types)
                        _Cell(value: chart.multiplier(attacker, defender)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Color _cellColor(double value) => switch (value) {
  0.0 => AppColors.surfaceSunken,
  0.5 => AppColors.crimson.withValues(alpha: .35),
  2.0 => AppColors.success.withValues(alpha: .55),
  _ => AppColors.container,
};

class _Cell extends StatelessWidget {
  final double value;
  const _Cell({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.chartCell,
    height: AppSizes.chartCell,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _cellColor(value),
      border: Border.all(color: AppColors.border, width: .5),
    ),
    child: Text(
      value == 1 ? '' : formatMultiplier(value),
      style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.lg,
    runSpacing: AppSpacing.sm,
    children: [
      for (final (value, text) in const [
        (2.0, 'Super effective'),
        (1.0, 'Neutral'),
        (0.5, 'Not very effective'),
        (0.0, 'No effect'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.md,
              height: AppSpacing.md,
              decoration: BoxDecoration(
                color: _cellColor(value),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${formatMultiplier(value)} $text',
              style: AppTypography.caption,
            ),
          ],
        ),
    ],
  );
}

class _Matchups extends StatelessWidget {
  final String label;
  final List<String> types;
  final String empty;
  const _Matchups({
    required this.label,
    required this.types,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        if (types.isEmpty)
          Text(empty, style: AppTypography.bodySmall)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final type in types) TypePill(type: type)],
          ),
      ],
    ),
  );
}
