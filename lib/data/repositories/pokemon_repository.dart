import '../datasources/pokeapi_client.dart';
import '../datasources/pokemon_cache.dart';
import '../models/ability.dart';
import '../models/evolution_chain.dart';
import '../models/fetch_source.dart';
import '../models/habitat.dart';
import '../models/pokemon_detail.dart';
import '../models/pokemon_index_entry.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_summary.dart';
import '../models/pokemon_type_data.dart';
import '../models/type_defenses.dart';

/// The repository is the only thing the presentation layer talks to.
/// It decides cache-vs-network so screens/providers stay free of that logic,
/// and reports where each result came from as a [FetchSource].
/// Outcome of one network request, reported to [PokemonRepository.onNetwork]:
/// `latency` is null when the request failed.
typedef NetworkEvent = ({Duration? latency, int cacheEntries});

class PokemonRepository {
  final PokeApiClient _client;
  final PokemonCache _cache;

  /// Called after every network request (not for cache hits), so the UI
  /// can show real connection state without polling.
  final void Function(NetworkEvent event)? onNetwork;

  static const catalogIndexKey = 'all';
  static String typeDataKey(String type) => 'typedata:$type';

  PokemonRepository({
    required PokeApiClient client,
    required PokemonCache cache,
    this.onNetwork,
  }) : _client = client,
       _cache = cache;

  /// Cached API responses across all boxes.
  int get cacheEntryCount => _cache.entryCount;

  /// Name + id of every Pokemon (base species and forms), sorted by id.
  Future<(List<PokemonIndexEntry> entries, FetchSource source)>
  getPokemonIndex() => _cached(
    CacheBox.nameIndex,
    catalogIndexKey,
    _client.fetchPokemonIndex,
    encode: (entries) => [for (final e in entries) e.toCacheJson()],
    decode: (json) => [
      for (final e in json as List<dynamic>)
        PokemonIndexEntry.fromCacheJson(e as Map<String, dynamic>),
    ],
  );

  /// Members and damage relations of one type, from GET /type/{name}.
  Future<(PokemonTypeData data, FetchSource source)> getTypeData(String type) =>
      _cached(
        CacheBox.nameIndex,
        typeDataKey(type),
        () => _client.fetchTypeData(type),
        encode: (data) => data.toCacheJson(),
        decode: (json) =>
            PokemonTypeData.fromCacheJson(json as Map<String, dynamic>),
      );

  Future<(PokemonDetail detail, FetchSource source)> getPokemonDetail(int id) =>
      _cached(
        CacheBox.detail,
        '$id',
        () => _client.fetchPokemonDetail(id),
        encode: (detail) => detail.toCacheJson(),
        decode: (json) =>
            PokemonDetail.fromCacheJson(json as Map<String, dynamic>),
      );

  Future<(PokemonSpecies species, FetchSource source)> getSpecies(
    int speciesId,
  ) => _cached(
    CacheBox.species,
    '$speciesId',
    () => _client.fetchSpecies(speciesId),
    encode: (species) => species.toCacheJson(),
    decode: (json) =>
        PokemonSpecies.fromCacheJson(json as Map<String, dynamic>),
  );

  Future<(EvolutionChain chain, FetchSource source)> getEvolutionChain(
    int chainId,
  ) => _cached(
    CacheBox.evolutionChain,
    '$chainId',
    () => _client.fetchEvolutionChain(chainId),
    encode: (chain) => chain.toCacheJson(),
    decode: (json) =>
        EvolutionChain.fromCacheJson(json as Map<String, dynamic>),
  );

  /// Names of every habitat.
  Future<(List<String> names, FetchSource source)> getHabitatNames() => _cached(
    CacheBox.habitat,
    'all',
    _client.fetchHabitatNames,
    encode: (names) => names,
    decode: (json) => (json as List<dynamic>).cast<String>(),
  );

  Future<(PokemonHabitat habitat, FetchSource source)> getHabitat(
    String name,
  ) => _cached(
    CacheBox.habitat,
    'habitat:$name',
    () => _client.fetchHabitat(name),
    encode: (habitat) => habitat.toCacheJson(),
    decode: (json) =>
        PokemonHabitat.fromCacheJson(json as Map<String, dynamic>),
  );

  /// Every ability, for the Ability Codex search.
  Future<(List<AbilityEntry> abilities, FetchSource source)>
  getAbilityIndex() => _cached(
    CacheBox.ability,
    'all',
    _client.fetchAbilityIndex,
    encode: (entries) => [
      for (final e in entries) {'id': e.id, 'name': e.name},
    ],
    decode: (json) => [
      for (final e in json as List<dynamic>)
        (
          id: (e as Map<String, dynamic>)['id'] as int,
          name: e['name'] as String,
        ),
    ],
  );

  Future<(AbilityDetail ability, FetchSource source)> getAbility(String name) =>
      _cached(
        CacheBox.ability,
        'ability:$name',
        () => _client.fetchAbility(name),
        encode: (ability) => ability.toCacheJson(),
        decode: (json) =>
            AbilityDetail.fromCacheJson(json as Map<String, dynamic>),
      );

  /// Resolves index entries (name + id only) to cards with types, stats and
  /// artwork. Each record goes through the detail cache.
  Future<(List<PokemonSummary> items, FetchSource source)> getPokemonSummaries(
    List<PokemonIndexEntry> entries,
  ) async {
    final details = await Future.wait(
      entries.map((entry) => getPokemonDetail(entry.id)),
    );
    return (
      [for (final (detail, _) in details) detail.toSummary()],
      FetchSource.combine([for (final (_, source) in details) source]),
    );
  }

  /// Defensive type matrix for a Pokemon with [types], computed from the
  /// cached /type/{name} damage relations.
  Future<(TypeDefenses defenses, FetchSource source)> getTypeDefenses(
    List<String> types,
  ) async {
    final results = await Future.wait(types.map(getTypeData));
    return (
      TypeDefenses.calculate([for (final (data, _) in results) data.damage]),
      FetchSource.combine([for (final (_, source) in results) source]),
    );
  }

  /// Bookmarked Pokemon, sorted by id. Stored without a TTL: these are the
  /// user's own records, not cached API responses.
  List<PokemonSummary> getSavedRecords() =>
      _cache.readSavedRecords().map(PokemonSummary.fromCacheJson).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  Future<void> saveRecord(PokemonSummary pokemon) =>
      _cache.writeSavedRecord(pokemon.toCacheJson());

  Future<void> deleteSavedRecord(int id) => _cache.deleteSavedRecord(id);

  /// Cache-then-network for one entry; the network path is timed so the UI
  /// can show the real request latency.
  Future<(T value, FetchSource source)> _cached<T>(
    CacheBox box,
    String key,
    Future<T> Function() fetch, {
    required Object Function(T value) encode,
    required T Function(Object json) decode,
  }) async {
    final cached = _cache.read(box, key);
    if (cached != null) return (decode(cached), const CacheHit());

    final stopwatch = Stopwatch()..start();
    final T fresh;
    try {
      fresh = await fetch();
    } catch (_) {
      onNetwork?.call((latency: null, cacheEntries: _cache.entryCount));
      rethrow;
    }
    stopwatch.stop();
    await _cache.write(box, key, encode(fresh));
    onNetwork?.call((
      latency: stopwatch.elapsed,
      cacheEntries: _cache.entryCount,
    ));
    return (fresh, NetworkFetch(stopwatch.elapsed));
  }
}
