import '../../core/constants.dart';

/// Lightweight model for the list screen: name, artwork, and types only —
/// exactly what the acceptance criteria ask the list view to show.
class PokemonSummary {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;

  const PokemonSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
  });

  factory PokemonSummary.fromDetailJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final imageUrl = pokemonArtworkUrl(id);

    final typesJson = json['types'] as List<dynamic>? ?? [];
    final types = typesJson
        .map(
          (t) =>
              ((t as Map<String, dynamic>)['type']
                      as Map<String, dynamic>)['name']
                  as String,
        )
        .toList();

    return PokemonSummary(
      id: id,
      name: json['name'] as String,
      imageUrl: imageUrl,
      types: types,
    );
  }

  factory PokemonSummary.fromCacheJson(Map<String, dynamic> json) {
    return PokemonSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: pokemonArtworkUrl(json['id'] as int),
      types: (json['types'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'types': types,
  };
}
