import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/pokemon_list_provider.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/error_view.dart';
import '../widgets/search_bar.dart';
import '../widgets/field_shell.dart';
import '../providers/app_navigation_provider.dart';
import 'pokemon_detail_screen.dart';

/// Start fetching the next page when the user is this close to the bottom.
const double _loadMoreThreshold = 600;

class PokemonListScreen extends ConsumerWidget {
  const PokemonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pokemonListProvider);
    final notifier = ref.read(pokemonListProvider.notifier);
    final status = state.status;
    final width = MediaQuery.of(context).size.width;
    final columns = Breakpoints.columnsFor(width);

    final isDesktop = width >= Breakpoints.desktop;
    final cardAspectRatio = width >= Breakpoints.desktop
        ? 0.94
        : width >= Breakpoints.tablet
        ? 0.88
        : 0.82;
    final types = switch (status) {
      ListLoaded(:final items) || ListLoadingMore(:final items) =>
        items.expand((item) => item.types).toSet().toList()..sort(),
      _ => const <String>[],
    };

    // A failed page waits for an explicit retry instead of auto-retrying.
    final canLoadMore = switch (status) {
      ListLoaded(hasMore: true, loadMoreError: null) => true,
      _ => false,
    };

    // Covers both user scrolling and content growth (a page that doesn't
    // fill the viewport yet), so short pages keep loading until it does.
    bool onScroll(Notification notification) {
      final metrics = switch (notification) {
        ScrollNotification(:final metrics) => metrics,
        ScrollMetricsNotification(:final metrics) => metrics,
        _ => null,
      };
      if (canLoadMore &&
          metrics != null &&
          metrics.axis == Axis.vertical &&
          metrics.extentAfter < _loadMoreThreshold) {
        Future.microtask(notifier.loadMore);
      }
      return false;
    }

    return FieldShell(
      active: AppDestination.specimenIndex,
      onRefresh: notifier.refresh,
      child: NotificationListener<Notification>(
        onNotification: onScroll,
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
              sliver: switch (status) {
                ListInitialLoading() => const SliverToBoxAdapter(
                  child: PokemonListSkeleton(),
                ),
                ListFailure(:final message) => SliverFillRemaining(
                  child: ErrorView(message: message, onRetry: notifier.refresh),
                ),
                ListEmpty() => SliverFillRemaining(
                  child: EmptyResultsView(
                    query: state.query,
                    onClear: () => notifier.setQuery(''),
                  ),
                ),
                ListLoaded(:final items) || ListLoadingMore(:final items) =>
                  state.visible(items).isEmpty
                      ? SliverFillRemaining(
                          child: EmptyResultsView(
                            query: state.query,
                            onClear: () => notifier.setQuery(''),
                          ),
                        )
                      : _PokemonGrid(
                          items: state.visible(items),
                          columns: columns,
                          aspectRatio: cardAspectRatio,
                        ),
              },
            ),
            SliverToBoxAdapter(
              child: switch (status) {
                ListLoadingMore() => const _PageLoadingIndicator(),
                ListLoaded(loadMoreError: final String message) => _PageRetry(
                  message: message,
                  onRetry: notifier.loadMore,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PokemonGrid extends StatelessWidget {
  final List<PokemonSummary> items;
  final int columns;
  final double aspectRatio;
  const _PokemonGrid({
    required this.items,
    required this.columns,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) => SliverGrid(
    delegate: SliverChildBuilderDelegate((context, index) {
      final pokemon = items[index];
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
    }, childCount: items.length),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspectRatio,
    ),
  );
}

/// Footer shown while the next page is being fetched.
class _PageLoadingIndicator extends StatelessWidget {
  const _PageLoadingIndicator();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 28),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.signal,
        ),
      ),
    ),
  );
}

/// Footer shown when the next page failed; the loaded items stay visible.
class _PageRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PageRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
    child: Column(
      children: [
        Text(
          'NEXT PAGE UNAVAILABLE / $message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.alert, fontSize: 10),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.signal,
            side: const BorderSide(color: AppTheme.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('RETRY PAGE'),
        ),
      ],
    ),
  );
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
