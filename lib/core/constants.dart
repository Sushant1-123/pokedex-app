import 'package:flutter/material.dart';

/// Central constants. Keeping these in one place makes the "sole data source"
/// and "1h cache" requirements easy to audit at a glance.
class AppConstants {
  AppConstants._();

  static const String pokeApiBaseUrl = 'https://pokeapi.co/api/v2';

  /// Requirement: cache API responses for 1 hour using a persistent store.
  static const Duration cacheTtl = Duration(hours: 1);

  /// How many Pokemon to request per page from PokeAPI's list endpoint.
  static const int pageSize = 40;

  /// Large enough to return every Pokemon in one request for the name index.
  static const int nameIndexLimit = 100000;

  static const String pokemonListBoxName = 'pokemon_list_cache';
  static const String pokemonDetailBoxName = 'pokemon_detail_cache';
  static const String pokemonIndexBoxName = 'pokemon_index_cache';
  static const String savedRecordsBoxName = 'saved_pokemon_records';
}

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
