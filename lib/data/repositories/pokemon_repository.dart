import '../datasources/pokeapi_client.dart';
import '../datasources/pokemon_cache.dart';
import '../models/pokemon_summary.dart';
import '../models/pokemon_detail.dart';

/// The repository is the only thing the presentation layer talks to.
/// It decides cache-vs-network so screens/providers stay free of that logic.
class PokemonRepository {
  final PokeApiClient _client;
  final PokemonCache _cache;

  PokemonRepository({
    required PokeApiClient client,
    required PokemonCache cache,
  })  : _client = client,
        _cache = cache;

  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonPage({
    required int offset,
    required int limit,
  }) async {
    final cacheKey = '$offset:$limit';
    final cached = _cache.readListPage(cacheKey);
    if (cached != null) {
      final items = cached
          .cast<Map<String, dynamic>>()
          .map(PokemonSummary.fromCacheJson)
          .toList();
      return (items, true);
    }

    final fresh = await _client.fetchPokemonPage(offset: offset, limit: limit);
    await _cache.writeListPage(
      cacheKey,
      fresh.map((p) => p.toCacheJson()).toList(),
    );
    return (fresh, false);
  }

  Future<(PokemonDetail detail, bool fromCache)> getPokemonDetail(
    String nameOrId,
  ) async {
    final cached = _cache.readDetail(nameOrId);
    if (cached != null) {
      return (PokemonDetail.fromCacheJson(cached), true);
    }

    final fresh = await _client.fetchPokemonDetail(nameOrId);
    await _cache.writeDetail(nameOrId, fresh.toCacheJson());
    return (fresh, false);
  }
}
