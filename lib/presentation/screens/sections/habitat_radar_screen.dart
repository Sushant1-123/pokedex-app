import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/design_tokens.dart';
import '../../../core/result.dart';
import '../../../core/theme.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/panel.dart';
import '../../widgets/pokemon_card.dart';
import '../../widgets/section_page.dart';

/// Habitats from /pokemon-habitat with their species counts and type mix.
class HabitatRadarScreen extends ConsumerWidget {
  const HabitatRadarScreen({super.key});

  static IconData _icon(String habitat) => switch (habitat) {
    'cave' => Icons.landscape_outlined,
    'forest' => Icons.forest_outlined,
    'grassland' => Icons.grass_rounded,
    'mountain' => Icons.terrain_rounded,
    'rare' => Icons.auto_awesome_outlined,
    'rough-terrain' => Icons.filter_hdr_outlined,
    'sea' => Icons.waves_rounded,
    'urban' => Icons.location_city_rounded,
    'waters-edge' => Icons.water_rounded,
    _ => Icons.explore_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitatRadarProvider);
    final notifier = ref.read(habitatRadarProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= Breakpoints.desktop
        ? 3
        : width >= Breakpoints.tablet
        ? 2
        : 1;
    return SectionPage(
      destination: AppDestination.habitats,
      title: 'Habitat Radar',
      subtitle:
          'Habitat data in PokeAPI covers Generations I–III. Tap a habitat '
          'to see the species found there.',
      onRefresh: notifier.load,
      children: [
        switch (state.habitats) {
          Loading() => const Panel(child: SectionSkeleton(lines: 6)),
          Failure(:final message) => ErrorView(
            message: message,
            onRetry: notifier.load,
          ),
          Success(:final data) when data.isEmpty => const EmptyState(
            title: 'No Habitats Indexed',
            message: 'PokeAPI returned no habitats.',
          ),
          Success(:final data) => GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: columns == 1 ? 2.6 : 2.1,
            children: [
              for (final summary in data)
                _HabitatCard(
                  summary: summary,
                  icon: _icon(summary.habitat.name),
                  selected: state.selection?.name == summary.habitat.name,
                  onTap: () => notifier.select(summary.habitat),
                ),
            ],
          ),
        },
        if ((state.habitats, state.selection) case (
          Success(:final data),
          final GroupSelection selection,
        ))
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: '${titleCase(selection.name).toUpperCase()} SPECIES',
                  icon: _icon(selection.name),
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: notifier.close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                PokemonPageGrid(
                  page: selection.page,
                  onPage: (page) => notifier.select(
                    data
                        .firstWhere((s) => s.habitat.name == selection.name)
                        .habitat,
                    page: page,
                  ),
                  onRetry: () => notifier.select(
                    data
                        .firstWhere((s) => s.habitat.name == selection.name)
                        .habitat,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HabitatCard extends StatelessWidget {
  final HabitatSummary summary;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _HabitatCard({
    required this.summary,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mix = summary.typeMix.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = mix.fold(0, (sum, e) => sum + e.value);
    return Material(
      color: AppColors.container,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(
          color: selected ? AppColors.crimson : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.cyan),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      titleCase(summary.habitat.name),
                      style: AppTypography.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${summary.habitat.species.length} species',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: SizedBox(
                  height: AppSpacing.sm,
                  child: Row(
                    children: [
                      for (final entry in mix)
                        Expanded(
                          flex: entry.value,
                          child: Tooltip(
                            message: '${entry.key}: ${entry.value}',
                            child: ColoredBox(color: colorForType(entry.key)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                mix.isEmpty
                    ? 'No type data'
                    : mix
                          .take(3)
                          .map(
                            (e) =>
                                '${e.key.toUpperCase()} '
                                '${(e.value * 100 / total).round()}%',
                          )
                          .join('  ·  '),
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
