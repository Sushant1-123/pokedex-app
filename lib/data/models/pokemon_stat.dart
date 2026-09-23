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
