import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/result.dart';
import '../../data/models/pokemon_summary.dart';
import 'core_providers.dart';

/// Full state for the list screen: the loaded page, the current search query,
/// and the derived filtered list. Kept as one immutable class so the Notifier
/// has a single source of truth to update via `state = state.copyWith(...)`.
class PokemonListState {
  final Result<List<PokemonSummary>> result;
  final String query;
  final String? selectedType;

  const PokemonListState({
    required this.result,
    this.query = '',
    this.selectedType,
  });

  PokemonListState copyWith({
    Result<List<PokemonSummary>>? result,
    String? query,
    Object? selectedType = _keepType,
  }) {
    return PokemonListState(
      result: result ?? this.result,
      query: query ?? this.query,
      selectedType: identical(selectedType, _keepType)
          ? this.selectedType
          : selectedType as String?,
    );
  }

  static const _keepType = Object();

  /// Real-time filter by name — case-insensitive substring match.
  List<PokemonSummary> get filtered {
    final all = switch (result) {
      Success<List<PokemonSummary>>(data: final d) => d,
      _ => const <PokemonSummary>[],
    };
    final byType = selectedType == null
        ? all
        : all.where((p) => p.types.contains(selectedType)).toList();
    if (query.trim().isEmpty) return byType;
    final q = query.trim().toLowerCase();
    return byType.where((p) => p.name.toLowerCase().contains(q)).toList();
  }
}

/// Riverpod `NotifierProvider` (as required by the brief) managing the
/// Pokemon list: initial load, pull-to-refresh, and search filtering.
class PokemonListNotifier extends Notifier<PokemonListState> {
  @override
  PokemonListState build() {
    // Kick off the initial load right after the first state is produced.
    Future.microtask(load);
    return const PokemonListState(result: Loading());
  }

  Future<void> load() async {
    state = state.copyWith(result: const Loading());
    try {
      final repo = ref.read(pokemonRepositoryProvider);
      final (items, fromCache) = await repo.getPokemonPage(
        offset: 0,
        limit: AppConstants.pageSize,
      );
      state = state.copyWith(result: Success(items, fromCache: fromCache));
    } catch (e) {
      state = state.copyWith(result: Failure(e.toString()));
    }
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setType(String? type) {
    state = state.copyWith(selectedType: type);
  }

  Future<void> refresh() => load();
}

final pokemonListProvider =
    NotifierProvider<PokemonListNotifier, PokemonListState>(
  PokemonListNotifier.new,
);
