import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/ability.dart';
import 'package:pokedex_app/data/models/evolution_chain.dart';
import 'package:pokedex_app/data/models/fetch_source.dart';
import 'package:pokedex_app/data/models/habitat.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/data/models/pokemon_species.dart';
import 'package:pokedex_app/data/models/pokemon_stat.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/models/pokemon_type_data.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';
import 'package:pokedex_app/presentation/intro/intro_provider.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';

/// Index with [count] numbered base species plus the named [extra] entries.
List<PokemonIndexEntry> catalog(
  int count, {
  List<PokemonIndexEntry> extra = const [],
}) {
  final named = {for (final e in extra) e.id: e};
  return [
    for (var id = 1; id <= count; id++)
      named.remove(id) ?? PokemonIndexEntry(id: id, name: 'pokemon-$id'),
    ...named.values,
  ]..sort((a, b) => a.id.compareTo(b.id));
}

/// In-memory repository: never touches the network or Hive. Individual
/// detail requests can be held back ([hold]) or made to fail ([failIds]).
class FakeRepository extends PokemonRepository {
  FakeRepository({
    List<PokemonIndexEntry>? index,
    this.typeMembers = const {},
    this.animatedSprites = const {},
  }) : index = index ?? catalog(3),
       super(client: PokeApiClient(), cache: PokemonCache());

  List<PokemonIndexEntry> index;
  final Map<String, List<int>> typeMembers;
  final Map<int, String> animatedSprites;

  int indexRequests = 0;
  final typeRequests = <String>[];
  final detailRequests = <int>[];
  final failIds = <int>{};
  final _gates = <int, Completer<void>>{};
  final saved = <int, PokemonSummary>{};

  /// Blocks getPokemonDetail([id]) until [release] is called.
  void hold(int id) => _gates[id] = Completer<void>();
  void release(int id) => _gates.remove(id)!.complete();

  @override
  Future<(List<PokemonIndexEntry>, FetchSource)> getPokemonIndex() async {
    indexRequests++;
    return (index, const CacheHit());
  }

  @override
  Future<(PokemonTypeData, FetchSource)> getTypeData(String type) async {
    typeRequests.add(type);
    final ids = typeMembers[type] ?? const [];
    return (
      PokemonTypeData(
        name: type,
        members: index.where((e) => ids.contains(e.id)).toList(),
        damage: const TypeDamageRelations(),
      ),
      const CacheHit(),
    );
  }

  @override
  Future<(PokemonDetail, FetchSource)> getPokemonDetail(int id) async {
    detailRequests.add(id);
    await _gates[id]?.future;
    if (failIds.contains(id)) throw PokeApiException('offline');
    return (detailFor(id), const NetworkFetch(Duration(milliseconds: 42)));
  }

  PokemonDetail detailFor(int id) {
    final name =
        index.where((e) => e.id == id).firstOrNull?.name ?? 'pokemon-$id';
    final types = [
      for (final MapEntry(key: type, value: ids) in typeMembers.entries)
        if (ids.contains(id)) type,
    ];
    return PokemonDetail(
      id: id,
      name: name,
      speciesId: id,
      imageUrl: pokemonArtworkUrl(id),
      animatedSpriteUrl: animatedSprites[id],
      types: types.isEmpty ? const ['normal'] : types,
      stats: const [
        PokemonStat(name: 'hp', base: 45),
        PokemonStat(name: 'attack', base: 49),
        PokemonStat(name: 'speed', base: 90),
      ],
      abilities: const [
        PokemonAbility(name: 'overgrow', isHidden: false),
        PokemonAbility(name: 'chlorophyll', isHidden: true),
      ],
      heightM: .7,
      weightKg: 6.9,
      baseExperience: 64,
    );
  }

  @override
  Future<(PokemonSpecies, FetchSource)> getSpecies(int speciesId) async => (
    PokemonSpecies(
      id: speciesId,
      name: 'pokemon-$speciesId',
      genus: 'Seed Pokémon',
      flavorText: 'A strange seed was planted on its back at birth.',
      genderRatio: const Gendered(femaleEighths: 1),
      evolutionChainId: null,
      generation: 'I',
      growthRate: 'medium-slow',
      isLegendary: false,
      isMythical: false,
    ),
    const CacheHit(),
  );

  @override
  Future<(EvolutionChain, FetchSource)> getEvolutionChain(int chainId) async =>
      (
        EvolutionChain(
          id: chainId,
          root: const EvolutionStage(speciesId: 1, name: 'pokemon-1'),
        ),
        const CacheHit(),
      );

  @override
  Future<(List<String>, FetchSource)> getHabitatNames() async =>
      (const ['cave', 'forest'], const CacheHit());

  @override
  Future<(PokemonHabitat, FetchSource)> getHabitat(String name) async => (
    PokemonHabitat(name: name, species: index.take(3).toList()),
    const CacheHit(),
  );

  @override
  Future<(List<AbilityEntry>, FetchSource)> getAbilityIndex() async => (
    const [(id: 65, name: 'overgrow'), (id: 66, name: 'blaze')],
    const CacheHit(),
  );

  @override
  Future<(AbilityDetail, FetchSource)> getAbility(String name) async => (
    AbilityDetail(
      id: 65,
      name: name,
      shortEffect: 'Powers up Grass-type moves when HP is low.',
      effect: null,
      generation: 'III',
      pokemon: [(pokemon: index.first, isHidden: false)],
    ),
    const CacheHit(),
  );

  @override
  String? cachedSpeciesColor(int id) => null;

  @override
  List<PokemonSummary> getSavedRecords() =>
      saved.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<void> saveRecord(PokemonSummary pokemon) async =>
      saved[pokemon.id] = pokemon;

  @override
  Future<void> deleteSavedRecord(int id) async => saved.remove(id);
}

/// Skips the launch intro in widget tests that are about other screens.
class FinishedIntroNotifier extends IntroNotifier {
  @override
  IntroPhase build() => IntroPhase.done;
}

List<Override> appOverrides(
  FakeRepository repository, {
  bool skipIntro = true,
}) => [
  pokemonRepositoryProvider.overrideWithValue(repository),
  if (skipIntro) introProvider.overrideWith(FinishedIntroNotifier.new),
];
