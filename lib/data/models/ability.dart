import '../../core/constants.dart';
import 'pokemon_index_entry.dart';
import 'pokemon_species.dart';

/// One row of GET /ability?limit=100000.
typedef AbilityEntry = ({int id, String name});

AbilityEntry abilityEntryFromJson(Map<String, dynamic> json) => (
  id: idFromResourceUrl(json['url'] as String),
  name: json['name'] as String,
);

/// A Pokemon that can have an ability, and whether it is its hidden one.
typedef AbilityHolder = ({PokemonIndexEntry pokemon, bool isHidden});

/// Data from GET /ability/{name}.
class AbilityDetail {
  final int id;
  final String name;

  /// English short effect, falling back to the newest English flavor text
  /// (recent abilities have no effect entries yet).
  final String? shortEffect;

  /// English full effect text.
  final String? effect;

  /// Roman numeral of the generation, e.g. "III".
  final String? generation;
  final List<AbilityHolder> pokemon;

  const AbilityDetail({
    required this.id,
    required this.name,
    required this.shortEffect,
    required this.effect,
    required this.generation,
    required this.pokemon,
  });

  factory AbilityDetail.fromJson(Map<String, dynamic> json) {
    bool isEnglish(Map<String, dynamic> entry) =>
        (entry['language'] as Map<String, dynamic>)['name'] == 'en';
    final effects = (json['effect_entries'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where(isEnglish);
    final flavors = (json['flavor_text_entries'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where(isEnglish);
    final effect = effects.firstOrNull;
    final generation = json['generation'] as Map<String, dynamic>?;
    return AbilityDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      shortEffect: switch ((effect, flavors.lastOrNull)) {
        (final Map<String, dynamic> e, _) => cleanFlavorText(
          e['short_effect'] as String,
        ),
        (null, final Map<String, dynamic> f) => cleanFlavorText(
          f['flavor_text'] as String,
        ),
        _ => null,
      },
      effect: effect == null
          ? null
          : cleanFlavorText(effect['effect'] as String),
      generation: (generation?['name'] as String?)
          ?.replaceFirst('generation-', '')
          .toUpperCase(),
      pokemon: [
        for (final p in json['pokemon'] as List<dynamic>? ?? const [])
          (
            pokemon: PokemonIndexEntry.fromResourceJson(
              (p as Map<String, dynamic>)['pokemon'] as Map<String, dynamic>,
            ),
            isHidden: p['is_hidden'] as bool? ?? false,
          ),
      ],
    );
  }

  factory AbilityDetail.fromCacheJson(Map<String, dynamic> json) =>
      AbilityDetail(
        id: json['id'] as int,
        name: json['name'] as String,
        shortEffect: json['shortEffect'] as String?,
        effect: json['effect'] as String?,
        generation: json['generation'] as String?,
        pokemon: [
          for (final p in json['pokemon'] as List<dynamic>)
            (
              pokemon: PokemonIndexEntry.fromCacheJson(
                (p as Map<String, dynamic>)['pokemon'] as Map<String, dynamic>,
              ),
              isHidden: p['isHidden'] as bool,
            ),
        ],
      );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'shortEffect': shortEffect,
    'effect': effect,
    'generation': generation,
    'pokemon': [
      for (final p in pokemon)
        {'pokemon': p.pokemon.toCacheJson(), 'isHidden': p.isHidden},
    ],
  };
}
