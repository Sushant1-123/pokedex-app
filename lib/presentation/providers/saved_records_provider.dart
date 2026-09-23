import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/models/pokemon_summary.dart';
import 'core_providers.dart';

class SavedRecordsNotifier extends Notifier<Result<List<PokemonSummary>>> {
  @override
  Result<List<PokemonSummary>> build() {
    Future.microtask(load);
    return const Loading();
  }

  void load() {
    try {
      final records = ref
          .read(pokemonCacheProvider)
          .readSavedRecords()
          .map(PokemonSummary.fromCacheJson)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      state = Success(records, fromCache: true);
    } catch (error) {
      state = Failure(error.toString());
    }
  }

  Future<void> toggle(PokemonSummary pokemon) async {
    final cache = ref.read(pokemonCacheProvider);
    final current = switch (state) {
      Success<List<PokemonSummary>>(data: final records) => records,
      _ => cache.readSavedRecords().map(PokemonSummary.fromCacheJson).toList(),
    };
    final exists = current.any((record) => record.id == pokemon.id);
    if (exists) {
      await cache.deleteSavedRecord(pokemon.id);
    } else {
      await cache.writeSavedRecord(pokemon.toCacheJson());
    }
    load();
  }

  Future<void> remove(PokemonSummary pokemon) async {
    await ref.read(pokemonCacheProvider).deleteSavedRecord(pokemon.id);
    load();
  }

  bool contains(int id) {
    final records = switch (state) {
      Success<List<PokemonSummary>>(data: final value) => value,
      _ => const <PokemonSummary>[],
    };
    return records.any((record) => record.id == id);
  }
}

final savedRecordsProvider =
    NotifierProvider<SavedRecordsNotifier, Result<List<PokemonSummary>>>(
  SavedRecordsNotifier.new,
);
