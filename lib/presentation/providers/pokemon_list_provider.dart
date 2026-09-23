import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/fetch_source.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../../data/models/pokemon_summary.dart';
import 'core_providers.dart';

/// What the list area shows. Sealed so the screen's `switch` has to handle
/// every case.
sealed class PokemonListStatus {
  const PokemonListStatus();
}

/// Resolving the index / type members for the current query; the screen
/// shows skeletons.
final class ListInitialLoading extends PokemonListStatus {
  const ListInitialLoading();
}

/// The index or type lookup failed, so there are no pages to show.
final class ListFailure extends PokemonListStatus {
  final String message;
  const ListFailure(this.message);
}

/// Nothing matches the current query / type filter.
final class ListEmpty extends PokemonListStatus {
  const ListEmpty();
}

/// One page of the current results. [page] is 1-based.
sealed class ListPaged extends PokemonListStatus {
  final int page;
  final int pageCount;

  /// Number of matching Pokemon across all pages.
  final int totalCount;
  const ListPaged({
    required this.page,
    required this.pageCount,
    required this.totalCount,
  });
}

final class ListPageLoading extends ListPaged {
  const ListPageLoading({
    required super.page,
    required super.pageCount,
    required super.totalCount,
  });
}

final class ListLoaded extends ListPaged {
  final List<PokemonSummary> items;
  const ListLoaded(
    this.items, {
    required super.page,
    required super.pageCount,
    required super.totalCount,
  });
}

/// The page's records could not be loaded; the pager stays usable and the
/// page can be retried.
final class ListPageFailure extends ListPaged {
  final String message;
  const ListPageFailure(
    this.message, {
    required super.page,
    required super.pageCount,
    required super.totalCount,
  });
}

/// Full state for the list screen, kept as one immutable class so the
/// Notifier has a single source of truth to update via `copyWith`.
class PokemonListState {
  final PokemonListStatus status;
  final String query;
  final String? selectedType;

  /// Source of the last completed load, for the latency readout.
  final FetchSource? lastSource;

  const PokemonListState({
    required this.status,
    this.query = '',
    this.selectedType,
    this.lastSource,
  });

  PokemonListState copyWith({
    PokemonListStatus? status,
    String? query,
    Object? selectedType = _keepType,
    FetchSource? lastSource,
  }) {
    return PokemonListState(
      status: status ?? this.status,
      query: query ?? this.query,
      selectedType: identical(selectedType, _keepType)
          ? this.selectedType
          : selectedType as String?,
      lastSource: lastSource ?? this.lastSource,
    );
  }

  static const _keepType = Object();

  bool get hasQuery => query.trim().isNotEmpty;

  /// True when the list shows search/type matches rather than the catalog.
  bool get isFiltered => hasQuery || selectedType != null;
}

/// Filters the name index for the list. Without a query only base species
/// are listed (the directory); a query matches names case-insensitively
/// (and an exact id, optionally prefixed with #) across base species and
/// alternate forms.
List<PokemonIndexEntry> searchPokemonIndex(
  List<PokemonIndexEntry> entries,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries.where((e) => e.isBaseSpecies).toList();
  final id = int.tryParse(q.startsWith('#') ? q.substring(1) : q);
  return entries
      .where((e) => e.name.toLowerCase().contains(q) || e.id == id)
      .toList();
}

/// Number of pages needed for [totalCount] results (at least one).
int pageCountFor(int totalCount) =>
    totalCount <= 0 ? 1 : (totalCount / AppConstants.pageSize).ceil();

/// Riverpod `NotifierProvider` (as required by the brief) managing the
/// Pokemon list: the numbered catalog pages, debounced search across the
/// full name index, the type filter and refresh.
class PokemonListNotifier extends Notifier<PokemonListState> {
  Timer? _debounce;

  /// Bumped on every reload and page change; an async result is applied
  /// only while its generation is still current, so a stale response never
  /// overwrites a newer one.
  int _generation = 0;

  /// Every entry matching the current query / type, in id order.
  List<PokemonIndexEntry> _matches = const [];

  /// Last loaded catalog page, restored as-is when the filters are cleared
  /// so the directory comes back without refetching.
  ({List<PokemonIndexEntry> matches, ListLoaded page})? _catalog;

  @override
  PokemonListState build() {
    ref.onDispose(() => _debounce?.cancel());
    // Kick off the initial load right after the first state is produced.
    Future.microtask(_reload);
    return const PokemonListState(status: ListInitialLoading());
  }

  /// Updates the query right away (so the field stays in sync) and searches
  /// once typing pauses. Clearing it reloads immediately.
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
    if (type == state.selectedType) return;
    _debounce?.cancel();
    state = state.copyWith(selectedType: type);
    _reload();
  }

  void clearFilters() {
    _debounce?.cancel();
    state = state.copyWith(query: '', selectedType: null);
    _reload();
  }

  /// Drops the cached catalog snapshot and reloads the current view.
  Future<void> refresh() {
    _debounce?.cancel();
    _catalog = null;
    return _reload();
  }

  /// Shows page [page] (1-based) of the current results.
  Future<void> goToPage(int page) async {
    final status = state.status;
    if (status is! ListPaged || page < 1 || page > status.pageCount) return;
    if (status is ListLoaded && status.page == page) return;
    await _loadPage(page, ++_generation);
  }

  /// Retries the current page after a [ListPageFailure].
  Future<void> retryPage() async {
    if (state.status case ListPageFailure(:final page)) {
      await _loadPage(page, ++_generation);
    }
  }

  /// Resolves the matches for the current query and type, then loads the
  /// first page. Anything that changes what the list shows goes through here.
  Future<void> _reload() async {
    final generation = ++_generation;
    final query = state.query;
    final type = state.selectedType;

    final catalog = _catalog;
    if (!state.isFiltered && catalog != null) {
      _matches = catalog.matches;
      state = state.copyWith(status: catalog.page);
      return;
    }

    state = state.copyWith(status: const ListInitialLoading());
    try {
      final (matches, source) = await _findMatches(query, type);
      if (generation != _generation) return;
      _matches = matches;
      if (matches.isEmpty) {
        state = state.copyWith(status: const ListEmpty(), lastSource: source);
        return;
      }
      await _loadPage(1, generation, indexSource: source);
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(status: ListFailure(e.toString()));
    }
  }

  /// Without a type the candidates are the full name index; with one they
  /// are that type's members from /type/{name}, so a query on top yields
  /// the intersection of both.
  Future<(List<PokemonIndexEntry>, FetchSource)> _findMatches(
    String query,
    String? type,
  ) async {
    final repository = ref.read(pokemonRepositoryProvider);
    final (candidates, source) = type == null
        ? await repository.getPokemonIndex()
        : await repository
              .getTypeData(type)
              .then((result) => (result.$1.members, result.$2));
    return (searchPokemonIndex(candidates, query), source);
  }

  Future<void> _loadPage(
    int page,
    int generation, {
    FetchSource? indexSource,
  }) async {
    final totalCount = _matches.length;
    final pageCount = pageCountFor(totalCount);
    state = state.copyWith(
      status: ListPageLoading(
        page: page,
        pageCount: pageCount,
        totalCount: totalCount,
      ),
    );
    try {
      final slice = _matches
          .skip((page - 1) * AppConstants.pageSize)
          .take(AppConstants.pageSize)
          .toList();
      final (items, pageSource) = await ref
          .read(pokemonRepositoryProvider)
          .getPokemonSummaries(slice);
      if (generation != _generation) return;
      final loaded = ListLoaded(
        items,
        page: page,
        pageCount: pageCount,
        totalCount: totalCount,
      );
      if (!state.isFiltered) _catalog = (matches: _matches, page: loaded);
      state = state.copyWith(
        status: loaded,
        lastSource: FetchSource.combine([?indexSource, pageSource]),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: ListPageFailure(
          e.toString(),
          page: page,
          pageCount: pageCount,
          totalCount: totalCount,
        ),
      );
    }
  }
}

final pokemonListProvider =
    NotifierProvider<PokemonListNotifier, PokemonListState>(
      PokemonListNotifier.new,
    );
