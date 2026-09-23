import '../../core/constants.dart';
import 'pokemon_summary.dart';

/// A single base stat (hp, attack, defense, etc).
class PokemonStat {
  final String name;
  final int base;
  const PokemonStat({required this.name, required this.base});

  factory PokemonStat.fromJson(Map<String, dynamic> json) => PokemonStat(
    name: (json['stat'] as Map<String, dynamic>)['name'] as String,
    base: json['base_stat'] as int,
  );

  Map<String, dynamic> toCacheJson() => {'name': name, 'base': base};
  factory PokemonStat.fromCacheJson(Map<String, dynamic> json) =>
      PokemonStat(name: json['name'] as String, base: json['base'] as int);
}

/// Full detail payload for the detail screen: stats, abilities, height/weight,
/// plus everything the summary already carries (name, image, types).
class PokemonDetail {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;
  final List<PokemonStat> stats;
  final List<String> abilities;
  final double heightM;
  final double weightKg;

  const PokemonDetail({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.heightM,
    required this.weightKg,
  });

  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
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

    final statsJson = json['stats'] as List<dynamic>? ?? [];
    final stats = statsJson
        .map((s) => PokemonStat.fromJson(s as Map<String, dynamic>))
        .toList();

    final abilitiesJson = json['abilities'] as List<dynamic>? ?? [];
    final abilities = abilitiesJson
        .map(
          (a) =>
              ((a as Map<String, dynamic>)['ability']
                      as Map<String, dynamic>)['name']
                  as String,
        )
        .toList();

    // PokeAPI returns height in decimeters and weight in hectograms.
    final heightM = ((json['height'] as int? ?? 0) / 10);
    final weightKg = ((json['weight'] as int? ?? 0) / 10);

    return PokemonDetail(
      id: id,
      name: json['name'] as String,
      imageUrl: imageUrl,
      types: types,
      stats: stats,
      abilities: abilities,
      heightM: heightM,
      weightKg: weightKg,
    );
  }

  factory PokemonDetail.fromCacheJson(Map<String, dynamic> json) {
    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: pokemonArtworkUrl(json['id'] as int),
      types: (json['types'] as List<dynamic>).cast<String>(),
      stats: (json['stats'] as List<dynamic>)
          .map((s) => PokemonStat.fromCacheJson(s as Map<String, dynamic>))
          .toList(),
      abilities: (json['abilities'] as List<dynamic>).cast<String>(),
      heightM: (json['heightM'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
    );
  }

  PokemonSummary toSummary() =>
      PokemonSummary(id: id, name: name, imageUrl: imageUrl, types: types);

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'types': types,
    'stats': stats.map((s) => s.toCacheJson()).toList(),
    'abilities': abilities,
    'heightM': heightM,
    'weightKg': weightKg,
  };
}
