import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
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

  /// Narrows loaded [items] by the current type and name query.
  List<PokemonSummary> visible(List<PokemonSummary> items) {
    final byType = selectedType == null
        ? items
        : items.where((p) => p.types.contains(selectedType)).toList();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return byType;
    return byType.where((p) => p.name.toLowerCase().contains(q)).toList();
  }
}

typedef _Page = ({List<PokemonSummary> items, bool hasMore});

/// Riverpod `NotifierProvider` (as required by the brief) managing the
/// Pokemon list: paged loading, infinite scroll, refresh and filtering.
class PokemonListNotifier extends Notifier<PokemonListState> {
  /// Bumped on every reload; an async result is applied only while its
  /// generation is still current, so a stale response never overwrites a
  /// newer one.
  int _generation = 0;

  @override
  PokemonListState build() {
    // Kick off the initial load right after the first state is produced.
    Future.microtask(_reload);
    return const PokemonListState(status: ListInitialLoading());
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setType(String? type) {
    state = state.copyWith(selectedType: type);
  }

  Future<void> refresh() => _reload();

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
      state = state.copyWith(
        status: ListLoaded([
          ...status.items,
          ...page.items,
        ], hasMore: page.hasMore),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: ListLoaded(
          status.items,
          hasMore: true,
          loadMoreError: e.toString(),
        ),
      );
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    state = state.copyWith(status: const ListInitialLoading());
    try {
      final page = await _fetchPage(0);
      if (generation != _generation) return;
      state = state.copyWith(
        status: page.items.isEmpty
            ? const ListEmpty()
            : ListLoaded(page.items, hasMore: page.hasMore),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(status: ListFailure(e.toString()));
    }
  }

  Future<_Page> _fetchPage(int offset) async {
    final (items, _) = await ref
        .read(pokemonRepositoryProvider)
        .getPokemonPage(offset: offset, limit: AppConstants.pageSize);
    return (items: items, hasMore: items.length == AppConstants.pageSize);
  }
}

final pokemonListProvider =
    NotifierProvider<PokemonListNotifier, PokemonListState>(
      PokemonListNotifier.new,
    );
