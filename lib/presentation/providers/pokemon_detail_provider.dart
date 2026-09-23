import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/models/pokemon_detail.dart';
import 'core_providers.dart';

/// One Notifier instance per Pokemon (via `.family`), so navigating between
/// detail screens doesn't share or clobber state.
class PokemonDetailNotifier
    extends FamilyNotifier<Result<PokemonDetail>, String> {
  late final String nameOrId;

  @override
  Result<PokemonDetail> build(String arg) {
    nameOrId = arg;
    Future.microtask(load);
    return const Loading();
  }

  Future<void> load() async {
    state = const Loading();
    try {
      final repo = ref.read(pokemonRepositoryProvider);
      final (detail, fromCache) = await repo.getPokemonDetail(nameOrId);
      state = Success(detail, fromCache: fromCache);
    } catch (e) {
      state = Failure(e.toString());
    }
  }
}

final pokemonDetailProvider =
    NotifierProvider.family<
      PokemonDetailNotifier,
      Result<PokemonDetail>,
      String
    >(PokemonDetailNotifier.new);
