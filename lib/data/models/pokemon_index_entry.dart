import '../../core/constants.dart';

/// One row of the lightweight name index: just enough to search the whole
/// catalog by name and to resolve a match to its full record later.
class PokemonIndexEntry {
  final int id;
  final String name;

  const PokemonIndexEntry({required this.id, required this.name});

  /// Base species (id < 10000) make up the directory; alternate forms only
  /// show up in search results.
  bool get isBaseSpecies => id < AppConstants.formIdStart;

  /// Parses a PokeAPI named resource (`{name, url}`).
  factory PokemonIndexEntry.fromResourceJson(Map<String, dynamic> json) =>
      PokemonIndexEntry(
        id: idFromResourceUrl(json['url'] as String),
        name: json['name'] as String,
      );

  factory PokemonIndexEntry.fromCacheJson(Map<String, dynamic> json) =>
      PokemonIndexEntry(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toCacheJson() => {'id': id, 'name': name};
}
