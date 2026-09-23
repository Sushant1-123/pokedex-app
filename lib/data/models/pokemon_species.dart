import '../../core/constants.dart';

/// PokeAPI's `gender_rate`: the chance of being female in eighths, or -1 for
/// species without gender.
sealed class GenderRatio {
  const GenderRatio();

  factory GenderRatio.fromRate(int rate) =>
      rate < 0 ? const Genderless() : Gendered(femaleEighths: rate);

  int get rate => switch (this) {
    Genderless() => -1,
    Gendered(:final femaleEighths) => femaleEighths,
  };
}

final class Genderless extends GenderRatio {
  const Genderless();
}

final class Gendered extends GenderRatio {
  final int femaleEighths;
  const Gendered({required this.femaleEighths});

  double get femalePercent => femaleEighths * 12.5;
  double get malePercent => 100 - femalePercent;
}

/// Data from GET /pokemon-species/{id}.
class PokemonSpecies {
  final int id;
  final String name;

  /// English genus, e.g. "Flame Pokémon".
  final String? genus;

  /// Newest English Pokedex entry, with the game's line breaks removed.
  final String? flavorText;
  final GenderRatio genderRatio;
  final int? evolutionChainId;

  /// Roman numeral of the generation, e.g. "I".
  final String? generation;

  /// e.g. "medium-slow".
  final String? growthRate;
  final bool isLegendary;
  final bool isMythical;

  /// PokeAPI's Pokedex colour ("red", "blue", ...), if any.
  final String? color;

  const PokemonSpecies({
    required this.id,
    required this.name,
    required this.genus,
    required this.flavorText,
    required this.genderRatio,
    required this.evolutionChainId,
    required this.generation,
    required this.growthRate,
    required this.isLegendary,
    required this.isMythical,
    this.color,
  });

  factory PokemonSpecies.fromJson(Map<String, dynamic> json) {
    bool isEnglish(Map<String, dynamic> entry) =>
        (entry['language'] as Map<String, dynamic>)['name'] == 'en';
    final genera = (json['genera'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where(isEnglish);
    final flavors = (json['flavor_text_entries'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where(isEnglish);
    final chain = json['evolution_chain'] as Map<String, dynamic>?;
    final generation = json['generation'] as Map<String, dynamic>?;
    final growthRate = json['growth_rate'] as Map<String, dynamic>?;

    return PokemonSpecies(
      id: json['id'] as int,
      name: json['name'] as String,
      genus: genera.isEmpty ? null : genera.first['genus'] as String,
      flavorText: flavors.isEmpty
          ? null
          : cleanFlavorText(flavors.last['flavor_text'] as String),
      genderRatio: GenderRatio.fromRate(json['gender_rate'] as int? ?? -1),
      evolutionChainId: chain == null
          ? null
          : idFromResourceUrl(chain['url'] as String),
      generation: (generation?['name'] as String?)
          ?.replaceFirst('generation-', '')
          .toUpperCase(),
      growthRate: growthRate?['name'] as String?,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      color: (json['color'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  factory PokemonSpecies.fromCacheJson(Map<String, dynamic> json) =>
      PokemonSpecies(
        id: json['id'] as int,
        name: json['name'] as String,
        genus: json['genus'] as String?,
        flavorText: json['flavorText'] as String?,
        genderRatio: GenderRatio.fromRate(json['genderRate'] as int),
        evolutionChainId: json['evolutionChainId'] as int?,
        generation: json['generation'] as String?,
        growthRate: json['growthRate'] as String?,
        isLegendary: json['isLegendary'] as bool,
        isMythical: json['isMythical'] as bool,
        color: json['color'] as String?,
      );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'genus': genus,
    'flavorText': flavorText,
    'genderRate': genderRatio.rate,
    'evolutionChainId': evolutionChainId,
    'generation': generation,
    'growthRate': growthRate,
    'isLegendary': isLegendary,
    'isMythical': isMythical,
    'color': color,
  };
}

/// Flavor text keeps the games' hard line breaks, form feeds and soft
/// hyphens; this collapses them into plain prose.
String cleanFlavorText(String raw) => raw
    .replaceAll('\u00ad\n', '')
    .replaceAll(RegExp(r'[\s\u00ad]+'), ' ')
    .trim();
