import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/pokemon_list_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/field_shell.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/panel.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/status_readouts.dart';
import 'pokemon_detail_screen.dart';

class PokemonListScreen extends ConsumerStatefulWidget {
  const PokemonListScreen({super.key});

  @override
  ConsumerState<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends ConsumerState<PokemonListScreen> {
  final _scroll = ScrollController();
  final _searchFocus = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _scroll.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openDetail(PokemonSummary pokemon) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PokemonDetailScreen(
        pokemonId: pokemon.id,
        heroTag: 'pokemon-image-${pokemon.id}',
        initialImageUrl: pokemon.imageUrl,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(pokemonListProvider.select((s) => s.status), (previous, next) {
      final moved = switch ((previous, next)) {
        (ListPaged(page: final a), ListPaged(page: final b)) => a != b,
        _ => false,
      };
      if (moved && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
    final state = ref.watch(pokemonListProvider);
    final notifier = ref.read(pokemonListProvider.notifier);
    final status = state.status;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= Breakpoints.tablet;
    final padding = Breakpoints.pagePaddingFor(width);

    return FieldShell(
      active: AppDestination.specimenIndex,
      onRefresh: notifier.refresh,
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.keyK,
            meta: usesCommandKey,
            control: !usesCommandKey,
          ): _searchFocus.requestFocus,
        },
        child: Focus(
          autofocus: supportsKeyboardShortcuts,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = Breakpoints.columnsFor(width);
              final gap = Breakpoints.gridGapFor(width);
              final cellWidth =
                  (constraints.maxWidth - padding * 2 - gap * (columns - 1)) /
                  columns;
              final extent = pokemonCardExtent(cellWidth);
              return CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      padding,
                      AppSpacing.xl,
                      padding,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _DirectoryHeader(
                        state: state,
                        searchFocus: _searchFocus,
                        showShortcutHint: isWide && supportsKeyboardShortcuts,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    sliver: switch (status) {
                      ListInitialLoading() ||
                      ListPageLoading() => PokemonGridSkeleton(
                        columns: columns,
                        gap: gap,
                        cardExtent: extent,
                        count: columns * 2,
                      ),
                      ListFailure(:final message) => SliverToBoxAdapter(
                        child: ErrorView(
                          message: message,
                          onRetry: notifier.refresh,
                        ),
                      ),
                      ListPageFailure(:final message) => SliverToBoxAdapter(
                        child: ErrorView(
                          title: 'Page Synchronization Failed',
                          message: message,
                          onRetry: notifier.retryPage,
                        ),
                      ),
                      ListEmpty() => SliverToBoxAdapter(
                        child: EmptyResultsView(
                          query: state.query.trim(),
                          type: state.selectedType,
                          onClear: notifier.clearFilters,
                        ),
                      ),
                      ListLoaded(:final items) => SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => PokemonCard(
                            key: ValueKey(items[index].id),
                            index: index,
                            pokemon: items[index],
                            onTap: () => _openDetail(items[index]),
                          ),
                          childCount: items.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          mainAxisExtent: extent,
                        ),
                      ),
                    },
                  ),
                  if (status case ListPaged(
                    :final page,
                    :final pageCount,
                    :final totalCount,
                  ))
                    SliverPadding(
                      padding: EdgeInsets.all(padding),
                      sliver: SliverToBoxAdapter(
                        child: _PagerPanel(
                          page: page,
                          pageCount: pageCount,
                          totalCount: totalCount,
                          compact: !isWide,
                          stacked: width < Breakpoints.desktop,
                          state: state,
                          onPage: notifier.goToPage,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Status line, search, type ribbon and the specimen counter.
class _DirectoryHeader extends ConsumerWidget {
  final PokemonListState state;
  final FocusNode searchFocus;
  final bool showShortcutHint;

  const _DirectoryHeader({
    required this.state,
    required this.searchFocus,
    required this.showShortcutHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pokemonListProvider.notifier);
    final online = switch (state.status) {
      ListFailure() || ListPageFailure() => false,
      _ => true,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('FIELD SUB-NODE', style: AppTypography.title),
                  OnlineBadge(online: online),
                  LatencyReadout(source: state.lastSource),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Live specimen stream from pokeapi.co',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              PokemonSearchBar(
                query: state.query,
                onChanged: notifier.setQuery,
                focusNode: searchFocus,
                showShortcutHint: showShortcutHint,
              ),
              const SizedBox(height: AppSpacing.lg),
              _TypeRibbon(
                selected: state.selectedType,
                onSelected: notifier.setType,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              state.isFiltered ? 'Search Results' : 'Specimen Repository',
              style: AppTypography.headline,
            ),
            _Counter(state: state),
          ],
        ),
      ],
    );
  }
}

/// "1,025 specimens indexed", computed from the loaded index or matches.
class _Counter extends StatelessWidget {
  final PokemonListState state;
  const _Counter({required this.state});

  @override
  Widget build(BuildContext context) {
    final count = switch (state.status) {
      ListPaged(:final totalCount) => totalCount,
      ListEmpty() => 0,
      _ => null,
    };
    if (count == null) return const SizedBox.shrink();
    final noun = state.isFiltered ? 'matches' : 'specimens indexed';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.container,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '${formatCount(count)} $noun',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// 1025 -> "1,025".
String formatCount(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

class _TypeRibbon extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _TypeRibbon({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final types = pokemonTypeColors.keys.toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TypeChip(
            label: 'ALL TYPES',
            color: AppColors.crimson,
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final type in types)
            _TypeChip(
              label: type.toUpperCase(),
              color: colorForType(type),
              active: selected == type,
              onTap: () => onSelected(type),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.hover,
    margin: const EdgeInsets.only(right: AppSpacing.sm),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      boxShadow: [
        if (active)
          BoxShadow(
            color: color.withValues(alpha: .55),
            blurRadius: 14,
            spreadRadius: -2,
          ),
      ],
    ),
    child: Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? color : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide(color: active ? color : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? AppColors.textPrimary : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Showing 1 – 30 of 1,025" + the pager + the latency readout.
class _PagerPanel extends StatelessWidget {
  final int page;
  final int pageCount;
  final int totalCount;
  final bool compact;
  final bool stacked;
  final PokemonListState state;
  final ValueChanged<int> onPage;

  const _PagerPanel({
    required this.page,
    required this.pageCount,
    required this.totalCount,
    required this.compact,
    required this.stacked,
    required this.state,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final first = (page - 1) * AppConstants.pageSize + 1;
    final last = (page * AppConstants.pageSize).clamp(0, totalCount);
    final summary = Text(
      'Showing $first – $last of ${formatCount(totalCount)}',
      style: AppTypography.bodySmall,
    );
    final pager = PaginationBar(
      page: page,
      pageCount: pageCount,
      onPage: onPage,
      compact: compact,
    );
    return Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: stacked
          ? Column(
              children: [
                pager,
                const SizedBox(height: AppSpacing.md),
                summary,
                const SizedBox(height: AppSpacing.xs),
                LatencyReadout(source: state.lastSource),
              ],
            )
          : Row(
              children: [
                Expanded(child: summary),
                pager,
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: LatencyReadout(source: state.lastSource),
                  ),
                ),
              ],
            ),
    );
  }
}
