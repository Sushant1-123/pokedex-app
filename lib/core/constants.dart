import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Central constants. Keeping these in one place makes the "sole data source"
/// and "1h cache" requirements easy to audit at a glance.
class AppConstants {
  AppConstants._();

  static const String pokeApiBaseUrl = 'https://pokeapi.co/api/v2';

  /// Requirement: cache API responses for 1 hour using a persistent store.
  static const Duration cacheTtl = Duration(hours: 1);

  /// Cards per directory page. 30 fills the 2-, 3- and 5-column grids
  /// without a ragged last row.
  static const int pageSize = 30;

  /// PokeAPI numbers alternate forms (megas, regional forms, ...) from 10001
  /// upwards; everything below is a base species.
  static const int formIdStart = 10000;

  /// How long typing must pause before a search request is made.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Large enough to return every Pokemon in one request for the name index.
  static const int nameIndexLimit = 100000;

  /// Suffixed because the cached record shape changed (sprites, abilities);
  /// the old box is simply never read again.
  static const String pokemonDetailBoxName = 'pokemon_detail_cache_v2';
  static const String pokemonIndexBoxName = 'pokemon_index_cache';
  static const String pokemonSpeciesBoxName = 'pokemon_species_cache';
  static const String evolutionChainBoxName = 'evolution_chain_cache';
  static const String habitatBoxName = 'pokemon_habitat_cache';
  static const String abilityBoxName = 'ability_cache';

  /// At most this many requests in flight when loading many resources
  /// (e.g. all 18 types for the type chart).
  static const int maxConcurrentRequests = 4;
  static const String savedRecordsBoxName = 'saved_pokemon_records';
}

/// Takes the id from the trailing path segment of a PokeAPI resource url,
/// e.g. `.../pokemon-species/25/` -> 25.
int idFromResourceUrl(String url) =>
    int.parse(Uri.parse(url).pathSegments.lastWhere((s) => s.isNotEmpty));

String pokemonArtworkUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

/// Color per Pokemon type, used for the animated type badges and card accents.
/// Values match the conventional Pokemon type palette used across most Pokedex apps.
const Map<String, Color> pokemonTypeColors = {
  'normal': Color(0xFFA8A77A),
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'electric': Color(0xFFF7D02C),
  'grass': Color(0xFF7AC74C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
};

Color colorForType(String type) =>
    pokemonTypeColors[type.toLowerCase()] ?? const Color(0xFF68A090);

/// Glow colour for a Pokemon: its species colour mapped through
/// [AppColors.speciesGlow], falling back to its primary type colour.
Color pokemonGlowColor(String? speciesColor, List<String> types) =>
    AppColors.speciesGlow[speciesColor] ??
    (types.isEmpty ? AppColors.cyan : colorForType(types.first));

/// Maps [items] with [task], running at most [limit] tasks at a time, and
/// returns the results in input order.
Future<List<R>> mapWithConcurrency<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) task,
) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      results[i] = await task(items[i]);
    }
  }

  await Future.wait([
    for (var w = 0; w < limit && w < items.length; w++) worker(),
  ]);
  return results.cast<R>();
}
