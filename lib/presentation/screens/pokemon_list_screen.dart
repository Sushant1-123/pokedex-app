import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../providers/pokemon_list_provider.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/error_view.dart';
import '../widgets/search_bar.dart';
import '../widgets/field_shell.dart';
import '../providers/app_navigation_provider.dart';
import 'pokemon_detail_screen.dart';

class PokemonListScreen extends ConsumerWidget {
  const PokemonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pokemonListProvider);
    final notifier = ref.read(pokemonListProvider.notifier);
    final width = MediaQuery.of(context).size.width;
    final columns = Breakpoints.columnsFor(width);

    final isDesktop = width >= Breakpoints.desktop;
    final cardAspectRatio = width >= Breakpoints.desktop
        ? 0.94
        : width >= Breakpoints.tablet
        ? 0.88
        : 0.82;
    final types = switch (state.result) {
      Success(data: final items) =>
        items.expand((item) => item.types).toSet().toList()..sort(),
      _ => const <String>[],
    };

    return FieldShell(
      active: AppDestination.specimenIndex,
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 18,
              24,
              isDesktop ? 32 : 18,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SPECIMEN INDEX',
                    style: TextStyle(
                      color: AppTheme.signal,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RESEARCH-GRADE FIELD POKÉDEX',
                    style: TextStyle(
                      color: AppTheme.paper,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PokemonSearchBar(onChanged: notifier.setQuery),
                  const SizedBox(height: 14),
                  _TypeFilters(
                    types: types,
                    selected: state.selectedType,
                    onSelected: notifier.setType,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 18,
              vertical: 4,
            ).copyWith(bottom: 28),
            sliver: switch (state.result) {
              Loading() => const SliverToBoxAdapter(
                child: PokemonListSkeleton(),
              ),
              Failure(message: final msg) => SliverFillRemaining(
                child: ErrorView(message: msg, onRetry: notifier.refresh),
              ),
              Success() =>
                state.filtered.isEmpty
                    ? SliverFillRemaining(
                        child: EmptyResultsView(
                          query: state.query,
                          onClear: () => notifier.setQuery(''),
                        ),
                      )
                    : SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final pokemon = state.filtered[index];
                          return PokemonCard(
                            pokemon: pokemon,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PokemonDetailScreen(
                                  nameOrId: pokemon.name,
                                  heroTag: 'pokemon-image-${pokemon.id}',
                                ),
                              ),
                            ),
                          );
                        }, childCount: state.filtered.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: cardAspectRatio,
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

class _TypeFilters extends StatelessWidget {
  final List<String> types;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _TypeFilters({
    required this.types,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _FilterChip(
          label: 'ALL TYPES',
          active: selected == null,
          onTap: () => onSelected(null),
        ),
        ...types.map(
          (type) => _FilterChip(
            label: type.toUpperCase(),
            active: selected == type,
            onTap: () => onSelected(type),
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? AppTheme.ink : AppTheme.muted,
        backgroundColor: active ? AppTheme.signal : Colors.transparent,
        side: BorderSide(color: active ? AppTheme.signal : AppTheme.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
    ),
  );
}
