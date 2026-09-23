import 'pokemon_index_entry.dart';

/// Which attacking types hit this type for double, half or no damage
/// (`damage_relations` of GET /type/{name}).
class TypeDamageRelations {
  final List<String> doubleFrom;
  final List<String> halfFrom;
  final List<String> noFrom;

  const TypeDamageRelations({
    this.doubleFrom = const [],
    this.halfFrom = const [],
    this.noFrom = const [],
  });

  factory TypeDamageRelations.fromJson(Map<String, dynamic> json) {
    List<String> names(String key) => [
      for (final type in json[key] as List<dynamic>? ?? const [])
        (type as Map<String, dynamic>)['name'] as String,
    ];
    return TypeDamageRelations(
      doubleFrom: names('double_damage_from'),
      halfFrom: names('half_damage_from'),
      noFrom: names('no_damage_from'),
    );
  }

  factory TypeDamageRelations.fromCacheJson(Map<String, dynamic> json) =>
      TypeDamageRelations(
        doubleFrom: (json['doubleFrom'] as List<dynamic>).cast<String>(),
        halfFrom: (json['halfFrom'] as List<dynamic>).cast<String>(),
        noFrom: (json['noFrom'] as List<dynamic>).cast<String>(),
      );

  Map<String, dynamic> toCacheJson() => {
    'doubleFrom': doubleFrom,
    'halfFrom': halfFrom,
    'noFrom': noFrom,
  };
}

/// Everything the app uses from one GET /type/{name} response: the members
/// (for the type filter) and the damage relations (for the defensive matrix).
class PokemonTypeData {
  final String name;

  /// Every Pokemon of this type, sorted by id.
  final List<PokemonIndexEntry> members;
  final TypeDamageRelations damage;

  const PokemonTypeData({
    required this.name,
    required this.members,
    required this.damage,
  });

  factory PokemonTypeData.fromJson(Map<String, dynamic> json) =>
      PokemonTypeData(
        name: json['name'] as String,
        members: [
          for (final slot in json['pokemon'] as List<dynamic>? ?? const [])
            PokemonIndexEntry.fromResourceJson(
              (slot as Map<String, dynamic>)['pokemon'] as Map<String, dynamic>,
            ),
        ]..sort((a, b) => a.id.compareTo(b.id)),
        damage: TypeDamageRelations.fromJson(
          json['damage_relations'] as Map<String, dynamic>? ?? const {},
        ),
      );

  factory PokemonTypeData.fromCacheJson(Map<String, dynamic> json) =>
      PokemonTypeData(
        name: json['name'] as String,
        members: [
          for (final entry in json['members'] as List<dynamic>)
            PokemonIndexEntry.fromCacheJson(entry as Map<String, dynamic>),
        ],
        damage: TypeDamageRelations.fromCacheJson(
          json['damage'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toCacheJson() => {
    'name': name,
    'members': members.map((e) => e.toCacheJson()).toList(),
    'damage': damage.toCacheJson(),
  };
}
