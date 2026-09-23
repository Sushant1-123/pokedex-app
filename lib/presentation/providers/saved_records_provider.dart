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
      final records = ref.read(pokemonRepositoryProvider).getSavedRecords();
      state = Success(records, fromCache: true);
    } catch (error) {
      state = Failure(error.toString());
    }
  }

  Future<void> toggle(PokemonSummary pokemon) async {
    final repository = ref.read(pokemonRepositoryProvider);
    final saved = repository.getSavedRecords().any((r) => r.id == pokemon.id);
    if (saved) {
      await repository.deleteSavedRecord(pokemon.id);
    } else {
      await repository.saveRecord(pokemon);
    }
    load();
  }
}

final savedRecordsProvider =
    NotifierProvider<SavedRecordsNotifier, Result<List<PokemonSummary>>>(
      SavedRecordsNotifier.new,
    );
