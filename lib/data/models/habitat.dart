import 'pokemon_index_entry.dart';

/// Data from GET /pokemon-habitat/{name}. PokeAPI only has habitats for
/// Generations I-III.
class PokemonHabitat {
  final String name;

  /// Species living here; a species id is also its default Pokemon id.
  final List<PokemonIndexEntry> species;

  const PokemonHabitat({required this.name, required this.species});

  factory PokemonHabitat.fromJson(Map<String, dynamic> json) => PokemonHabitat(
    name: json['name'] as String,
    species: [
      for (final s in json['pokemon_species'] as List<dynamic>? ?? const [])
        PokemonIndexEntry.fromResourceJson(s as Map<String, dynamic>),
    ]..sort((a, b) => a.id.compareTo(b.id)),
  );

  factory PokemonHabitat.fromCacheJson(Map<String, dynamic> json) =>
      PokemonHabitat(
        name: json['name'] as String,
        species: [
          for (final s in json['species'] as List<dynamic>)
            PokemonIndexEntry.fromCacheJson(s as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toCacheJson() => {
    'name': name,
    'species': species.map((s) => s.toCacheJson()).toList(),
  };
}
