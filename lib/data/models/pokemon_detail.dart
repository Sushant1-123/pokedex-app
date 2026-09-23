import '../../core/constants.dart';
import 'pokemon_stat.dart';
import 'pokemon_summary.dart';

class PokemonAbility {
  final String name;
  final bool isHidden;
  const PokemonAbility({required this.name, required this.isHidden});

  Map<String, dynamic> toCacheJson() => {'name': name, 'isHidden': isHidden};
  factory PokemonAbility.fromCacheJson(Map<String, dynamic> json) =>
      PokemonAbility(
        name: json['name'] as String,
        isHidden: json['isHidden'] as bool,
      );
}

/// Full record from GET /pokemon/{id}: everything the detail screen needs
/// apart from species data (genus, flavor text, evolution chain).
class PokemonDetail {
  final int id;
  final String name;
  final int speciesId;
  final String? imageUrl;

  /// Animated Showdown sprite (GIF), when PokeAPI has one.
  final String? animatedSpriteUrl;

  /// `cries.latest`, falling back to `cries.legacy`.
  final String? cryUrl;
  final List<String> types;
  final List<PokemonStat> stats;
  final List<PokemonAbility> abilities;
  final double heightM;
  final double weightKg;
  final int? baseExperience;

  const PokemonDetail({
    required this.id,
    required this.name,
    required this.speciesId,
    required this.imageUrl,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.heightM,
    required this.weightKg,
    this.animatedSpriteUrl,
    this.cryUrl,
    this.baseExperience,
  });

  bool get isBaseSpecies => id < AppConstants.formIdStart;

  int get baseStatTotal => stats.fold(0, (sum, stat) => sum + stat.base);

  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>? ?? const {};
    final other = sprites['other'] as Map<String, dynamic>? ?? const {};
    String? sprite(String key) =>
        (other[key] as Map<String, dynamic>?)?['front_default'] as String?;
    final cries = json['cries'] as Map<String, dynamic>? ?? const {};
    final species = json['species'] as Map<String, dynamic>?;

    // PokeAPI returns height in decimeters and weight in hectograms.
    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesId: species == null
          ? json['id'] as int
          : idFromResourceUrl(species['url'] as String),
      imageUrl: sprite('official-artwork'),
      animatedSpriteUrl: sprite('showdown'),
      cryUrl: (cries['latest'] ?? cries['legacy']) as String?,
      types: [
        for (final t in json['types'] as List<dynamic>? ?? const [])
          ((t as Map<String, dynamic>)['type'] as Map<String, dynamic>)['name']
              as String,
      ],
      stats: [
        for (final s in json['stats'] as List<dynamic>? ?? const [])
          PokemonStat.fromJson(s as Map<String, dynamic>),
      ],
      abilities: [
        for (final a in json['abilities'] as List<dynamic>? ?? const [])
          PokemonAbility(
            name:
                ((a as Map<String, dynamic>)['ability']
                        as Map<String, dynamic>)['name']
                    as String,
            isHidden: a['is_hidden'] as bool? ?? false,
          ),
      ],
      heightM: (json['height'] as int? ?? 0) / 10,
      weightKg: (json['weight'] as int? ?? 0) / 10,
      baseExperience: json['base_experience'] as int?,
    );
  }

  factory PokemonDetail.fromCacheJson(Map<String, dynamic> json) {
    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      speciesId: json['speciesId'] as int,
      imageUrl: json['imageUrl'] as String?,
      animatedSpriteUrl: json['animatedSpriteUrl'] as String?,
      cryUrl: json['cryUrl'] as String?,
      types: (json['types'] as List<dynamic>).cast<String>(),
      stats: [
        for (final s in json['stats'] as List<dynamic>)
          PokemonStat.fromCacheJson(s as Map<String, dynamic>),
      ],
      abilities: [
        for (final a in json['abilities'] as List<dynamic>)
          PokemonAbility.fromCacheJson(a as Map<String, dynamic>),
      ],
      heightM: (json['heightM'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      baseExperience: json['baseExperience'] as int?,
    );
  }

  PokemonSummary toSummary() => PokemonSummary(
    id: id,
    name: name,
    imageUrl: imageUrl,
    types: types,
    stats: stats,
  );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'speciesId': speciesId,
    'imageUrl': imageUrl,
    'animatedSpriteUrl': animatedSpriteUrl,
    'cryUrl': cryUrl,
    'types': types,
    'stats': stats.map((s) => s.toCacheJson()).toList(),
    'abilities': abilities.map((a) => a.toCacheJson()).toList(),
    'heightM': heightM,
    'weightKg': weightKg,
    'baseExperience': baseExperience,
  };
}
