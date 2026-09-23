import '../datasources/pokeapi_client.dart';
import '../datasources/pokemon_cache.dart';
import '../models/pokemon_summary.dart';
import '../models/pokemon_detail.dart';
import '../models/pokemon_index_entry.dart';

/// The repository is the only thing the presentation layer talks to.
/// It decides cache-vs-network so screens/providers stay free of that logic.
class PokemonRepository {
  final PokeApiClient _client;
  final PokemonCache _cache;

  static const catalogIndexKey = 'all';
  static String typeIndexKey(String type) => 'type:$type';

  PokemonRepository({
    required PokeApiClient client,
    required PokemonCache cache,
  }) : _client = client,
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

    final details = await _client.fetchPokemonPage(
      offset: offset,
      limit: limit,
    );
    // The page already downloaded every full record, so cache those too:
    // opening a card or computing telemetry then needs no extra request.
    await Future.wait(
      details.map((d) => _cache.writeDetail(d.name, d.toCacheJson())),
    );
    final items = details.map((d) => d.toSummary()).toList();
    await _cache.writeListPage(
      cacheKey,
      items.map((p) => p.toCacheJson()).toList(),
    );
    return (items, false);
  }

  /// Resolves index matches (name + id only) to cards with types and
  /// artwork. Each record goes through the detail cache.
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonSummaries(
    List<PokemonIndexEntry> entries,
  ) async {
    final details = await Future.wait(
      entries.map((entry) => getPokemonDetail(entry.name)),
    );
    return (
      details.map((entry) => entry.$1.toSummary()).toList(),
      details.every((entry) => entry.$2),
    );
  }

  /// Name + id of every Pokemon, used to search beyond the loaded pages.
  Future<(List<PokemonIndexEntry> entries, bool fromCache)> getPokemonIndex() =>
      _getIndex(catalogIndexKey, _client.fetchPokemonIndex);

  /// Name + id of every Pokemon of [type], across the whole catalog.
  Future<(List<PokemonIndexEntry> entries, bool fromCache)> getTypeMembers(
    String type,
  ) => _getIndex(typeIndexKey(type), () => _client.fetchTypeMembers(type));

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

  /// Bookmarked Pokemon, sorted by id. Stored without a TTL: these are the
  /// user's own records, not cached API responses.
  List<PokemonSummary> getSavedRecords() =>
      _cache.readSavedRecords().map(PokemonSummary.fromCacheJson).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  Future<void> saveRecord(PokemonSummary pokemon) =>
      _cache.writeSavedRecord(pokemon.toCacheJson());

  Future<void> deleteSavedRecord(int id) => _cache.deleteSavedRecord(id);

  Future<(List<PokemonIndexEntry> entries, bool fromCache)> _getIndex(
    String key,
    Future<List<PokemonIndexEntry>> Function() fetch,
  ) async {
    final cached = _cache.readIndex(key);
    if (cached != null) {
      final entries = cached
          .cast<Map<String, dynamic>>()
          .map(PokemonIndexEntry.fromCacheJson)
          .toList();
      return (entries, true);
    }

    final fresh = await fetch();
    await _cache.writeIndex(key, fresh.map((e) => e.toCacheJson()).toList());
    return (fresh, false);
  }
}
