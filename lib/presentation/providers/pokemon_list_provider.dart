import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../../data/models/pokemon_summary.dart';
import 'core_providers.dart';

/// What the list area shows. Sealed so the screen's `switch` has to handle
/// every case: initial loading, failure, empty results, loaded, loading more.
sealed class PokemonListStatus {
  const PokemonListStatus();
}

/// The first page is loading; the screen shows skeletons.
final class ListInitialLoading extends PokemonListStatus {
  const ListInitialLoading();
}

/// The first page failed, so there is nothing to show but a retry.
final class ListFailure extends PokemonListStatus {
  final String message;
  const ListFailure(this.message);
}

/// Nothing matches the current query / type filter.
final class ListEmpty extends PokemonListStatus {
  const ListEmpty();
}

/// Items are on screen. [loadMoreError] is set when the last next-page
/// request failed, so the footer can offer a retry.
final class ListLoaded extends PokemonListStatus {
  final List<PokemonSummary> items;
  final bool hasMore;
  final String? loadMoreError;
  const ListLoaded(this.items, {required this.hasMore, this.loadMoreError});
}

/// Items are on screen and the next page is being fetched.
final class ListLoadingMore extends PokemonListStatus {
  final List<PokemonSummary> items;
  const ListLoadingMore(this.items);
}

/// Full state for the list screen, kept as one immutable class so the
/// Notifier has a single source of truth to update via `copyWith`.
class PokemonListState {
  final PokemonListStatus status;
  final String query;
  final String? selectedType;

  const PokemonListState({
    required this.status,
    this.query = '',
    this.selectedType,
  });

  PokemonListState copyWith({
    PokemonListStatus? status,
    String? query,
    Object? selectedType = _keepType,
  }) {
    return PokemonListState(
      status: status ?? this.status,
      query: query ?? this.query,
      selectedType: identical(selectedType, _keepType)
          ? this.selectedType
          : selectedType as String?,
    );
  }

  static const _keepType = Object();

  bool get hasQuery => query.trim().isNotEmpty;

  /// Narrows loaded [items] by the selected type.
  List<PokemonSummary> visible(List<PokemonSummary> items) {
    if (selectedType == null) return items;
    return items.where((p) => p.types.contains(selectedType)).toList();
  }
}

/// Case-insensitive name `contains` match over the name index. A numeric
/// query (optionally prefixed with #) also matches the Pokemon with that id.
List<PokemonIndexEntry> searchPokemonIndex(
  List<PokemonIndexEntry> entries,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  final id = int.tryParse(q.startsWith('#') ? q.substring(1) : q);
  return entries
      .where((e) => e.name.toLowerCase().contains(q) || e.id == id)
      .toList();
}

typedef _Page = ({List<PokemonSummary> items, bool hasMore});

/// Riverpod `NotifierProvider` (as required by the brief) managing the
/// Pokemon list: the paginated catalog, debounced search across the full
/// name index, infinite scroll and refresh.
class PokemonListNotifier extends Notifier<PokemonListState> {
  Timer? _debounce;

  /// Bumped on every reload; an async result is applied only while its
  /// generation is still current, so a stale response never overwrites a
  /// newer one.
  int _generation = 0;

  /// Index entries matching the active search, or null while browsing the
  /// catalog page by page.
  List<PokemonIndexEntry>? _matches;

  /// Last loaded catalog, restored as-is when the search is cleared so the
  /// paginated list comes back without refetching.
  ListLoaded? _catalog;

  @override
  PokemonListState build() {
    ref.onDispose(() => _debounce?.cancel());
    // Kick off the initial load right after the first state is produced.
    Future.microtask(_reload);
    return const PokemonListState(status: ListInitialLoading());
  }

  /// Updates the query right away (so the field stays in sync) and searches
  /// once typing pauses. Clearing it restores the catalog immediately.
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
    _debounce?.cancel();
    if (state.hasQuery) {
      _debounce = Timer(AppConstants.searchDebounce, _reload);
    } else {
      _reload();
    }
  }

  void setType(String? type) {
    state = state.copyWith(selectedType: type);
  }

  /// Drops the cached catalog snapshot and reloads the current view.
  Future<void> refresh() {
    _debounce?.cancel();
    _catalog = null;
    return _reload();
  }

  /// Appends the next page. No-op unless a loaded list has more to fetch,
  /// so it is safe to call on every scroll event near the bottom.
  Future<void> loadMore() async {
    final status = state.status;
    if (status is! ListLoaded || !status.hasMore) return;
    final generation = _generation;
    state = state.copyWith(status: ListLoadingMore(status.items));
    try {
      final page = await _fetchPage(status.items.length);
      if (generation != _generation) return;
      _show(
        ListLoaded([...status.items, ...page.items], hasMore: page.hasMore),
      );
    } catch (e) {
      if (generation != _generation) return;
      _show(
        ListLoaded(status.items, hasMore: true, loadMoreError: e.toString()),
      );
    }
  }

  /// Loads the first page for the current query. Anything that changes what
  /// the list shows goes through here, and bumps [_generation].
  Future<void> _reload() async {
    final generation = ++_generation;
    final query = state.query;
    final searching = state.hasQuery;

    if (!searching) {
      _matches = null;
      final catalog = _catalog;
      if (catalog != null) {
        _show(catalog);
        return;
      }
    }

    state = state.copyWith(status: const ListInitialLoading());
    try {
      if (searching) {
        final (index, _) = await ref
            .read(pokemonRepositoryProvider)
            .getPokemonIndex();
        if (generation != _generation) return;
        _matches = searchPokemonIndex(index, query);
      }
      final page = await _fetchPage(0);
      if (generation != _generation) return;
      _show(
        page.items.isEmpty
            ? const ListEmpty()
            : ListLoaded(page.items, hasMore: page.hasMore),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(status: ListFailure(e.toString()));
    }
  }

  /// Next page of either the catalog or the current search matches.
  Future<_Page> _fetchPage(int offset) async {
    final repository = ref.read(pokemonRepositoryProvider);
    final matches = _matches;
    if (matches == null) {
      final (items, _) = await repository.getPokemonPage(
        offset: offset,
        limit: AppConstants.pageSize,
      );
      return (items: items, hasMore: items.length == AppConstants.pageSize);
    }
    final slice = matches.skip(offset).take(AppConstants.pageSize).toList();
    final (items, _) = await repository.getPokemonSummaries(slice);
    return (items: items, hasMore: offset + slice.length < matches.length);
  }

  void _show(PokemonListStatus status) {
    if (_matches == null && status is ListLoaded) _catalog = status;
    state = state.copyWith(status: status);
  }
}

final pokemonListProvider =
    NotifierProvider<PokemonListNotifier, PokemonListState>(
      PokemonListNotifier.new,
    );
