import 'pokemon_type_data.dart';

/// Attacking-vs-defending type chart built from each type's
/// `damage_relations`: `multiplier(attacker, defender)` is 0, 0.5, 1 or 2.
class TypeChart {
  /// Types in display order (rows = attackers, columns = defenders).
  final List<String> types;
  final Map<String, Map<String, double>> _cells;

  const TypeChart._(this.types, this._cells);

  /// [relations] maps each defending type to how it takes damage.
  factory TypeChart.build(
    List<String> types,
    Map<String, TypeDamageRelations> relations,
  ) {
    final cells = <String, Map<String, double>>{
      for (final attacker in types)
        attacker: <String, double>{
          for (final defender in types)
            defender: switch (relations[defender]) {
              final TypeDamageRelations r when r.noFrom.contains(attacker) =>
                0.0,
              final TypeDamageRelations r
                  when r.doubleFrom.contains(attacker) =>
                2.0,
              final TypeDamageRelations r when r.halfFrom.contains(attacker) =>
                0.5,
              _ => 1.0,
            },
        },
    };
    return TypeChart._(types, cells);
  }

  double multiplier(String attacker, String defender) =>
      _cells[attacker]?[defender] ?? 1;

  /// Defending types [type] hits for double damage.
  List<String> strongAgainst(String type) => [
    for (final d in types)
      if (multiplier(type, d) == 2) d,
  ];

  /// Attacking types that hit [type] for double damage.
  List<String> weakTo(String type) => [
    for (final a in types)
      if (multiplier(a, type) == 2) a,
  ];

  /// Attacking types [type] is immune to.
  List<String> immuneTo(String type) => [
    for (final a in types)
      if (multiplier(a, type) == 0) a,
  ];
}
