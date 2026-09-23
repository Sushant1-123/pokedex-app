import 'pokemon_stat.dart';

/// Lightweight model for directory cards: name, artwork, types and the base
/// stats shown in the card footer.
class PokemonSummary {
  final int id;
  final String name;

  /// Official artwork, or null when PokeAPI has none (the UI then shows a
  /// designed placeholder).
  final String? imageUrl;
  final List<String> types;
  final List<PokemonStat> stats;

  const PokemonSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    this.stats = const [],
  });

  /// Saved records written by older versions have no `stats`, so that field
  /// is optional here.
  factory PokemonSummary.fromCacheJson(Map<String, dynamic> json) {
    return PokemonSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      types: (json['types'] as List<dynamic>).cast<String>(),
      stats: [
        for (final stat in json['stats'] as List<dynamic>? ?? const [])
          PokemonStat.fromCacheJson(stat as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'types': types,
    'stats': stats.map((s) => s.toCacheJson()).toList(),
  };
}
