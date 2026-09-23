import 'pokemon_type_data.dart';

/// An attacking type and the damage multiplier it deals to the Pokemon.
typedef TypeMatchup = ({String type, double multiplier});

/// Defensive type matrix of a Pokemon: how much damage each attacking type
/// deals to it. For dual types the multipliers of both types multiply, so a
/// shared weakness becomes 4x and a weakness cancelled by an immunity 0x.
class TypeDefenses {
  /// Multiplier above 1 (2x, 4x), strongest first.
  final List<TypeMatchup> weaknesses;

  /// Multiplier between 0 and 1 (0.5x, 0.25x), strongest resistance first.
  final List<TypeMatchup> resistances;

  /// Attacking types that deal no damage (0x).
  final List<String> immunities;

  const TypeDefenses({
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
  });

  factory TypeDefenses.calculate(Iterable<TypeDamageRelations> defending) {
    final multipliers = <String, double>{};
    void apply(List<String> types, double factor) {
      for (final type in types) {
        multipliers[type] = (multipliers[type] ?? 1) * factor;
      }
    }

    for (final relations in defending) {
      apply(relations.doubleFrom, 2);
      apply(relations.halfFrom, 0.5);
      apply(relations.noFrom, 0);
    }

    final weaknesses = <TypeMatchup>[];
    final resistances = <TypeMatchup>[];
    final immunities = <String>[];
    for (final MapEntry(key: type, value: multiplier) in multipliers.entries) {
      switch (multiplier) {
        case 0.0:
          immunities.add(type);
        case > 1.0:
          weaknesses.add((type: type, multiplier: multiplier));
        case < 1.0:
          resistances.add((type: type, multiplier: multiplier));
      }
    }
    int byMultiplierThenName(TypeMatchup a, TypeMatchup b, int direction) {
      final byMultiplier = direction * a.multiplier.compareTo(b.multiplier);
      return byMultiplier != 0 ? byMultiplier : a.type.compareTo(b.type);
    }

    weaknesses.sort((a, b) => byMultiplierThenName(a, b, -1));
    resistances.sort((a, b) => byMultiplierThenName(a, b, 1));
    immunities.sort();
    return TypeDefenses(
      weaknesses: weaknesses,
      resistances: resistances,
      immunities: immunities,
    );
  }
}
