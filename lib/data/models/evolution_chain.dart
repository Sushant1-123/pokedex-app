import '../../core/constants.dart';

/// How a stage evolves from the previous one. PokeAPI lists several method
/// entries per stage (one per game generation); [EvolutionTrigger.fromDetails]
/// picks the most informative one.
sealed class EvolutionTrigger {
  const EvolutionTrigger();

  static EvolutionTrigger? fromDetails(List<dynamic> details) {
    final entries = details.cast<Map<String, dynamic>>();
    if (entries.isEmpty) return null;
    String? named(Map<String, dynamic> entry, String key) =>
        (entry[key] as Map<String, dynamic>?)?['name'] as String?;
    String trigger(Map<String, dynamic> entry) => named(entry, 'trigger') ?? '';

    for (final entry in entries) {
      if (entry['min_level'] case final int level) return LevelUp(level);
    }
    for (final entry in entries) {
      if (named(entry, 'item') case final String item) return UseItem(item);
    }
    for (final entry in entries) {
      if (trigger(entry) == 'trade') return Trade(named(entry, 'held_item'));
    }
    for (final entry in entries) {
      if (entry['min_happiness'] != null) {
        final time = entry['time_of_day'] as String? ?? '';
        return Friendship(time.isEmpty ? null : time);
      }
    }
    return OtherMethod(trigger(entries.first));
  }

  static EvolutionTrigger fromCacheJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    return switch (json['kind']) {
      'level' => LevelUp(int.parse(value!)),
      'item' => UseItem(value!),
      'trade' => Trade(value),
      'friendship' => Friendship(value),
      _ => OtherMethod(value ?? ''),
    };
  }

  Map<String, dynamic> toCacheJson() => switch (this) {
    LevelUp(:final level) => {'kind': 'level', 'value': '$level'},
    UseItem(:final item) => {'kind': 'item', 'value': item},
    Trade(:final heldItem) => {'kind': 'trade', 'value': heldItem},
    Friendship(:final timeOfDay) => {'kind': 'friendship', 'value': timeOfDay},
    OtherMethod(:final trigger) => {'kind': 'other', 'value': trigger},
  };
}

final class LevelUp extends EvolutionTrigger {
  final int level;
  const LevelUp(this.level);
}

final class UseItem extends EvolutionTrigger {
  /// PokeAPI item name, e.g. "thunder-stone".
  final String item;
  const UseItem(this.item);
}

final class Trade extends EvolutionTrigger {
  final String? heldItem;
  const Trade(this.heldItem);
}

final class Friendship extends EvolutionTrigger {
  /// "day" or "night" when the time matters.
  final String? timeOfDay;
  const Friendship(this.timeOfDay);
}

/// Any other PokeAPI trigger (e.g. "shed", "spin"), kept by name.
final class OtherMethod extends EvolutionTrigger {
  final String trigger;
  const OtherMethod(this.trigger);
}

/// One species in an evolution tree. [trigger] is how it evolves from its
/// parent (null for the first stage).
class EvolutionStage {
  final int speciesId;
  final String name;
  final EvolutionTrigger? trigger;
  final List<EvolutionStage> evolvesTo;

  const EvolutionStage({
    required this.speciesId,
    required this.name,
    this.trigger,
    this.evolvesTo = const [],
  });

  factory EvolutionStage.fromJson(Map<String, dynamic> json) {
    final species = json['species'] as Map<String, dynamic>;
    return EvolutionStage(
      speciesId: idFromResourceUrl(species['url'] as String),
      name: species['name'] as String,
      trigger: EvolutionTrigger.fromDetails(
        json['evolution_details'] as List<dynamic>? ?? const [],
      ),
      evolvesTo: [
        for (final next in json['evolves_to'] as List<dynamic>? ?? const [])
          EvolutionStage.fromJson(next as Map<String, dynamic>),
      ],
    );
  }

  factory EvolutionStage.fromCacheJson(Map<String, dynamic> json) {
    final trigger = json['trigger'] as Map<String, dynamic>?;
    return EvolutionStage(
      speciesId: json['speciesId'] as int,
      name: json['name'] as String,
      trigger: trigger == null ? null : EvolutionTrigger.fromCacheJson(trigger),
      evolvesTo: [
        for (final next in json['evolvesTo'] as List<dynamic>)
          EvolutionStage.fromCacheJson(next as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'speciesId': speciesId,
    'name': name,
    'trigger': trigger?.toCacheJson(),
    'evolvesTo': evolvesTo.map((next) => next.toCacheJson()).toList(),
  };
}

/// Data from GET /evolution-chain/{id}.
class EvolutionChain {
  final int id;
  final EvolutionStage root;

  const EvolutionChain({required this.id, required this.root});

  factory EvolutionChain.fromJson(Map<String, dynamic> json) => EvolutionChain(
    id: json['id'] as int,
    root: EvolutionStage.fromJson(json['chain'] as Map<String, dynamic>),
  );

  factory EvolutionChain.fromCacheJson(Map<String, dynamic> json) =>
      EvolutionChain(
        id: json['id'] as int,
        root: EvolutionStage.fromCacheJson(
          json['root'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toCacheJson() => {'id': id, 'root': root.toCacheJson()};

  /// Stages grouped by depth: `[[eevee], [vaporeon, jolteon, ...]]`. A
  /// branching chain has more than one species in a stage.
  List<List<EvolutionStage>> get stages {
    final stages = <List<EvolutionStage>>[];
    var current = [root];
    while (current.isNotEmpty) {
      stages.add(current);
      current = [for (final stage in current) ...stage.evolvesTo];
    }
    return stages;
  }

  bool get isSingleStage => root.evolvesTo.isEmpty;
}
