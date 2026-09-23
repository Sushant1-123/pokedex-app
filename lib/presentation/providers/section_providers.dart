import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/result.dart';
import '../../data/models/ability.dart';
import '../../data/models/evolution_chain.dart';
import '../../data/models/habitat.dart';
import '../../data/models/pokemon_detail.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../../data/models/pokemon_type_data.dart';
import '../../data/models/type_chart.dart';
import '../../data/models/type_defenses.dart';
import 'core_providers.dart';
import 'name_index_provider.dart';

/// All 18 types in the conventional chart order.
final List<String> chartTypes = pokemonTypeColors.keys.toList();

/// Loads every type's /type data, at most
/// [AppConstants.maxConcurrentRequests] at a time.
Future<Map<String, PokemonTypeData>> _loadAllTypes(Ref ref) async {
  final repository = ref.read(pokemonRepositoryProvider);
  final results = await mapWithConcurrency(
    chartTypes,
    AppConstants.maxConcurrentRequests,
    (type) async => (await repository.getTypeData(type)).$1,
  );
  return {for (final data in results) data.name: data};
}

// ---------------------------------------------------------------------------
// Evolution Engine

/// A looked-up species and its full evolution chain.
typedef EvolutionLookup = ({PokemonIndexEntry entry, EvolutionChain chain});

/// Quick picks shown under the search: Eevee, Charmander, Ralts.
const evolutionQuickPicks = [
  PokemonIndexEntry(id: 133, name: 'eevee'),
  PokemonIndexEntry(id: 4, name: 'charmander'),
  PokemonIndexEntry(id: 280, name: 'ralts'),
];

/// Null until a species is picked (the screen then shows its empty state).
class EvolutionEngineNotifier extends Notifier<Result<EvolutionLookup>?> {
  int _generation = 0;
  PokemonIndexEntry? _last;

  @override
  Result<EvolutionLookup>? build() => null;

  /// Loads the chain for [entry]. Forms (id >= 10000) resolve through their
  /// species record, so any search result works.
  Future<void> open(PokemonIndexEntry entry) async {
    _last = entry;
    final generation = ++_generation;
    state = const Loading();
    try {
      final repository = ref.read(pokemonRepositoryProvider);
      final speciesId = entry.isBaseSpecies
          ? entry.id
          : (await repository.getPokemonDetail(entry.id)).$1.speciesId;
      final (species, _) = await repository.getSpecies(speciesId);
      final chainId = species.evolutionChainId;
      final chain = chainId == null
          ? EvolutionChain(
              id: 0,
              root: EvolutionStage(speciesId: species.id, name: species.name),
            )
          : (await repository.getEvolutionChain(chainId)).$1;
      if (generation != _generation) return;
      state = Success((entry: entry, chain: chain));
    } catch (e) {
      if (generation != _generation) return;
      state = Failure(e.toString());
    }
  }

  /// Reloads the last lookup after a failure.
  Future<void> retry() async {
    if (_last case final PokemonIndexEntry entry) await open(entry);
  }

  /// Opens a random base species' chain from the name index.
  Future<void> openRandom([math.Random? random]) async {
    final index = await _baseSpecies();
    if (index.isEmpty) return;
    await open(index[(random ?? math.Random()).nextInt(index.length)]);
  }

  Future<List<PokemonIndexEntry>> _baseSpecies() async {
    final (index, _) = await ref
        .read(pokemonRepositoryProvider)
        .getPokemonIndex();
    return index.where((e) => e.isBaseSpecies).toList();
  }
}

final evolutionEngineProvider =
    NotifierProvider<EvolutionEngineNotifier, Result<EvolutionLookup>?>(
      EvolutionEngineNotifier.new,
    );

// ---------------------------------------------------------------------------
// Type Spectra and Habitat Radar share a "selected group + paged members"
// panel.

/// A selected type or habitat and the current page of its Pokemon.
typedef GroupSelection = ({String name, Result<PokemonPage> page});

/// Loads [page] of [members] into a [GroupSelection] named [name], ignoring
/// results that arrive after a newer selection.
mixin _PagedGroup<T> on Notifier<T> {
  int _generation = 0;

  Future<void> loadGroupPage(
    String name,
    List<PokemonIndexEntry> members,
    int page,
    T Function(GroupSelection selection) apply,
  ) async {
    final generation = ++_generation;
    state = apply((name: name, page: const Loading()));
    try {
      final loaded = await loadPokemonPage(
        ref.read(pokemonRepositoryProvider),
        members,
        page,
      );
      if (generation != _generation) return;
      state = apply((name: name, page: Success(loaded)));
    } catch (e) {
      if (generation != _generation) return;
      state = apply((name: name, page: Failure(e.toString())));
    }
  }
}

/// Type chart plus the optional selected-type panel.
typedef TypeSpectraState = ({
  Result<TypeChart> chart,
  GroupSelection? selection,
});

class TypeSpectraNotifier extends Notifier<TypeSpectraState>
    with _PagedGroup<TypeSpectraState> {
  Map<String, PokemonTypeData> _types = const {};

  @override
  TypeSpectraState build() {
    Future.microtask(load);
    return (chart: const Loading(), selection: null);
  }

  Future<void> load() async {
    state = (chart: const Loading(), selection: state.selection);
    try {
      _types = await _loadAllTypes(ref);
      state = (
        chart: Success(
          TypeChart.build(chartTypes, {
            for (final MapEntry(:key, :value) in _types.entries)
              key: value.damage,
          }),
        ),
        selection: state.selection,
      );
    } catch (e) {
      state = (chart: Failure(e.toString()), selection: state.selection);
    }
  }

  /// Opens [type]'s panel at [page] of its base-species members.
  Future<void> select(String type, {int page = 1}) => loadGroupPage(
    type,
    [
      for (final e in _types[type]?.members ?? const <PokemonIndexEntry>[])
        if (e.isBaseSpecies) e,
    ],
    page,
    (selection) => (chart: state.chart, selection: selection),
  );

  void close() => state = (chart: state.chart, selection: null);
}

final typeSpectraProvider =
    NotifierProvider<TypeSpectraNotifier, TypeSpectraState>(
      TypeSpectraNotifier.new,
    );

// ---------------------------------------------------------------------------
// Habitat Radar

/// A habitat card: species count and how many of its species have each
/// type (a dual-type species counts once per type).
typedef HabitatSummary = ({PokemonHabitat habitat, Map<String, int> typeMix});

/// Habitat mix computed from /type members, without per-species requests.
Map<String, int> habitatTypeMix(
  PokemonHabitat habitat,
  Map<String, PokemonTypeData> types,
) {
  final ids = {for (final s in habitat.species) s.id};
  return {
    for (final MapEntry(key: type, value: data) in types.entries)
      if (data.members.where((m) => ids.contains(m.id)).length case final n
          when n > 0)
        type: n,
  };
}

typedef HabitatRadarState = ({
  Result<List<HabitatSummary>> habitats,
  GroupSelection? selection,
});

class HabitatRadarNotifier extends Notifier<HabitatRadarState>
    with _PagedGroup<HabitatRadarState> {
  @override
  HabitatRadarState build() {
    Future.microtask(load);
    return (habitats: const Loading(), selection: null);
  }

  Future<void> load() async {
    state = (habitats: const Loading(), selection: state.selection);
    try {
      final repository = ref.read(pokemonRepositoryProvider);
      final (names, _) = await repository.getHabitatNames();
      final habitats = await mapWithConcurrency(
        names,
        AppConstants.maxConcurrentRequests,
        (name) async => (await repository.getHabitat(name)).$1,
      );
      final types = await _loadAllTypes(ref);
      state = (
        habitats: Success([
          for (final habitat in habitats)
            (habitat: habitat, typeMix: habitatTypeMix(habitat, types)),
        ]),
        selection: state.selection,
      );
    } catch (e) {
      state = (habitats: Failure(e.toString()), selection: state.selection);
    }
  }

  Future<void> select(PokemonHabitat habitat, {int page = 1}) => loadGroupPage(
    habitat.name,
    habitat.species,
    page,
    (selection) => (habitats: state.habitats, selection: selection),
  );

  void close() => state = (habitats: state.habitats, selection: null);
}

final habitatRadarProvider =
    NotifierProvider<HabitatRadarNotifier, HabitatRadarState>(
      HabitatRadarNotifier.new,
    );

// ---------------------------------------------------------------------------
// Compare Lab

/// One Pokemon slot in Compare Lab.
sealed class ComparePick {
  final int id;
  const ComparePick(this.id);
}

final class PickLoading extends ComparePick {
  const PickLoading(super.id);
}

final class PickReady extends ComparePick {
  final PokemonDetail detail;
  final TypeDefenses defenses;
  PickReady(this.detail, this.defenses) : super(detail.id);
}

final class PickFailed extends ComparePick {
  final String message;
  const PickFailed(super.id, this.message);
}

/// The 2-3 Pokemon being compared.
class CompareNotifier extends Notifier<List<ComparePick>> {
  static const maxPicks = 3;

  @override
  List<ComparePick> build() => const [];

  /// Adds Pokemon [id]; returns false (and changes nothing) when the lab is
  /// full or it is already picked.
  bool add(int id) {
    if (state.length >= maxPicks || state.any((p) => p.id == id)) {
      return false;
    }
    state = [...state, PickLoading(id)];
    _load(id);
    return true;
  }

  void remove(int id) => state = [
    for (final p in state)
      if (p.id != id) p,
  ];

  Future<void> retry(int id) async {
    _replace(id, PickLoading(id));
    await _load(id);
  }

  Future<void> _load(int id) async {
    try {
      final repository = ref.read(pokemonRepositoryProvider);
      final (detail, _) = await repository.getPokemonDetail(id);
      final (defenses, _) = await repository.getTypeDefenses(detail.types);
      _replace(id, PickReady(detail, defenses));
    } catch (e) {
      _replace(id, PickFailed(id, e.toString()));
    }
  }

  void _replace(int id, ComparePick pick) =>
      state = [for (final p in state) p.id == id ? pick : p];
}

final compareProvider = NotifierProvider<CompareNotifier, List<ComparePick>>(
  CompareNotifier.new,
);

// ---------------------------------------------------------------------------
// Ability Codex

typedef AbilityCodexState = ({
  Result<List<AbilityEntry>> index,
  String query,
  ({String name, Result<AbilityDetail> detail})? selection,
});

class AbilityCodexNotifier extends Notifier<AbilityCodexState> {
  int _generation = 0;

  @override
  AbilityCodexState build() {
    Future.microtask(load);
    return (index: const Loading(), query: '', selection: null);
  }

  Future<void> load() async {
    state = (
      index: const Loading(),
      query: state.query,
      selection: state.selection,
    );
    try {
      final (index, _) = await ref
          .read(pokemonRepositoryProvider)
          .getAbilityIndex();
      state = (
        index: Success(index),
        query: state.query,
        selection: state.selection,
      );
    } catch (e) {
      state = (
        index: Failure(e.toString()),
        query: state.query,
        selection: state.selection,
      );
    }
  }

  void setQuery(String query) =>
      state = (index: state.index, query: query, selection: state.selection);

  /// Abilities whose name contains the query (spaces match hyphens).
  List<AbilityEntry> get matches {
    final q = state.query.trim().toLowerCase().replaceAll(' ', '-');
    return switch (state.index) {
      Success(:final data) => [
        for (final a in data)
          if (a.name.contains(q)) a,
      ],
      _ => const [],
    };
  }

  Future<void> select(String name) async {
    final generation = ++_generation;
    state = (
      index: state.index,
      query: state.query,
      selection: (name: name, detail: const Loading()),
    );
    try {
      final (detail, _) = await ref
          .read(pokemonRepositoryProvider)
          .getAbility(name);
      if (generation != _generation) return;
      state = (
        index: state.index,
        query: state.query,
        selection: (name: name, detail: Success(detail)),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = (
        index: state.index,
        query: state.query,
        selection: (name: name, detail: Failure(e.toString())),
      );
    }
  }
}

final abilityCodexProvider =
    NotifierProvider<AbilityCodexNotifier, AbilityCodexState>(
      AbilityCodexNotifier.new,
    );
