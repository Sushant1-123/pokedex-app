import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/result.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../../data/models/pokemon_summary.dart';
import '../../data/repositories/pokemon_repository.dart';
import 'core_providers.dart';
import 'pokemon_list_provider.dart';

/// The cached name index, shared by the pickers in Evolution Engine and
/// Compare Lab.
class NameIndexNotifier extends Notifier<Result<List<PokemonIndexEntry>>> {
  @override
  Result<List<PokemonIndexEntry>> build() {
    Future.microtask(load);
    return const Loading();
  }

  Future<void> load() async {
    state = const Loading();
    try {
      final (index, _) = await ref
          .read(pokemonRepositoryProvider)
          .getPokemonIndex();
      state = Success(index);
    } catch (e) {
      state = Failure(e.toString());
    }
  }

  /// Up to [limit] entries matching [query] (base species and forms).
  List<PokemonIndexEntry> suggestions(String query, {int limit = 8}) =>
      switch (state) {
        Success(:final data) when query.trim().isNotEmpty => searchPokemonIndex(
          data,
          query,
        ).take(limit).toList(),
        _ => const [],
      };
}

final nameIndexProvider =
    NotifierProvider<NameIndexNotifier, Result<List<PokemonIndexEntry>>>(
      NameIndexNotifier.new,
    );

/// One page of Pokemon cards resolved from index entries.
typedef PokemonPage = ({
  List<PokemonSummary> items,
  int page,
  int pageCount,
  int totalCount,
});

/// Loads page [page] (1-based) of [entries] as cards.
Future<PokemonPage> loadPokemonPage(
  PokemonRepository repository,
  List<PokemonIndexEntry> entries,
  int page,
) async {
  final slice = entries
      .skip((page - 1) * AppConstants.pageSize)
      .take(AppConstants.pageSize)
      .toList();
  final (items, _) = await repository.getPokemonSummaries(slice);
  return (
    items: items,
    page: page,
    pageCount: pageCountFor(entries.length),
    totalCount: entries.length,
  );
}
