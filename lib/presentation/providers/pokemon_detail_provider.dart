import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/models/evolution_chain.dart';
import '../../data/models/fetch_source.dart';
import '../../data/models/pokemon_detail.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../../data/models/pokemon_species.dart';
import '../../data/models/type_defenses.dart';
import 'core_providers.dart';

/// Adjacent base species for the breadcrumb navigation; null at the ends of
/// the dex (and for alternate forms, which have no neighbours).
typedef DexNeighbours = ({
  PokemonIndexEntry? previous,
  PokemonIndexEntry? next,
});

/// Everything on the detail screen. The record itself is required; the
/// other sections load afterwards and each has its own loading/error state,
/// so a failed species request doesn't blank the whole page.
class PokemonDossier {
  final PokemonDetail detail;
  final Result<PokemonSpecies> species;
  final Result<EvolutionChain> evolution;
  final Result<TypeDefenses> defenses;
  final DexNeighbours neighbours;

  const PokemonDossier({
    required this.detail,
    this.species = const Loading(),
    this.evolution = const Loading(),
    this.defenses = const Loading(),
    this.neighbours = (previous: null, next: null),
  });

  PokemonDossier copyWith({
    Result<PokemonSpecies>? species,
    Result<EvolutionChain>? evolution,
    Result<TypeDefenses>? defenses,
    DexNeighbours? neighbours,
  }) => PokemonDossier(
    detail: detail,
    species: species ?? this.species,
    evolution: evolution ?? this.evolution,
    defenses: defenses ?? this.defenses,
    neighbours: neighbours ?? this.neighbours,
  );
}

/// Neighbours of [id] among the base species in [index].
DexNeighbours neighboursOf(int id, List<PokemonIndexEntry> index) {
  final base = {
    for (final entry in index)
      if (entry.isBaseSpecies) entry.id: entry,
  };
  if (!base.containsKey(id)) return (previous: null, next: null);
  return (previous: base[id - 1], next: base[id + 1]);
}

/// One Notifier instance per Pokemon id (via `.family`), so navigating
/// between detail screens doesn't share or clobber state.
class PokemonDetailNotifier
    extends FamilyNotifier<Result<PokemonDossier>, int> {
  @override
  Result<PokemonDossier> build(int arg) {
    Future.microtask(load);
    return const Loading();
  }

  Future<void> load() async {
    state = const Loading();
    try {
      final (detail, source) = await ref
          .read(pokemonRepositoryProvider)
          .getPokemonDetail(arg);
      state = Success(
        PokemonDossier(detail: detail),
        fromCache: source is CacheHit,
      );
      await Future.wait([
        _loadSpeciesAndEvolution(detail),
        _loadDefenses(detail),
        _loadNeighbours(detail),
      ]);
    } catch (e) {
      state = Failure(e.toString());
    }
  }

  Future<void> _loadSpeciesAndEvolution(PokemonDetail detail) async {
    final repository = ref.read(pokemonRepositoryProvider);
    final PokemonSpecies species;
    try {
      (species, _) = await repository.getSpecies(detail.speciesId);
    } catch (e) {
      final failure = Failure<Never>(e.toString());
      _update((d) => d.copyWith(species: failure, evolution: failure));
      return;
    }
    _update((d) => d.copyWith(species: Success(species)));

    final chainId = species.evolutionChainId;
    if (chainId == null) {
      final single = EvolutionChain(
        id: 0,
        root: EvolutionStage(speciesId: species.id, name: species.name),
      );
      _update((d) => d.copyWith(evolution: Success(single)));
      return;
    }
    await _guard(
      () async => (await repository.getEvolutionChain(chainId)).$1,
      (result) =>
          (d) => d.copyWith(evolution: result),
    );
  }

  Future<void> _loadDefenses(PokemonDetail detail) => _guard(
    () async =>
        (await ref
                .read(pokemonRepositoryProvider)
                .getTypeDefenses(detail.types))
            .$1,
    (result) =>
        (d) => d.copyWith(defenses: result),
  );

  /// The breadcrumbs are optional chrome: if the index can't load they are
  /// simply hidden.
  Future<void> _loadNeighbours(PokemonDetail detail) async {
    try {
      final (index, _) = await ref
          .read(pokemonRepositoryProvider)
          .getPokemonIndex();
      final neighbours = neighboursOf(detail.id, index);
      _update((d) => d.copyWith(neighbours: neighbours));
    } catch (_) {
      // Leave both neighbours null, which hides the prev/next links.
    }
  }

  Future<void> _guard<T>(
    Future<T> Function() fetch,
    PokemonDossier Function(PokemonDossier) Function(Result<T> result) apply,
  ) async {
    try {
      _update(apply(Success(await fetch())));
    } catch (e) {
      _update(apply(Failure(e.toString())));
    }
  }

  void _update(PokemonDossier Function(PokemonDossier dossier) change) {
    if (state case Success(:final data, :final fromCache)) {
      state = Success(change(data), fromCache: fromCache);
    }
  }
}

final pokemonDetailProvider =
    NotifierProvider.family<PokemonDetailNotifier, Result<PokemonDossier>, int>(
      PokemonDetailNotifier.new,
    );

/// Session preference for the detail viewport: show the animated Showdown
/// sprite instead of the official artwork, when one exists.
class AnimatedSpriteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final animatedSpriteProvider = NotifierProvider<AnimatedSpriteNotifier, bool>(
  AnimatedSpriteNotifier.new,
);
