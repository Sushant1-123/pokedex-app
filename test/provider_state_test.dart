import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/core/result.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/pokemon_detail_provider.dart';

void main() {
  test('cache contract uses a one-hour TTL', () {
    expect(AppConstants.cacheTtl, const Duration(hours: 1));
  });

  test('detail provider reaches success through the repository', () async {
    final container = ProviderContainer(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(
          _FakeRepository(detail: _detail),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = pokemonDetailProvider('pikachu');
    expect(container.read(provider), isA<Loading<PokemonDetail>>());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final result = container.read(provider);
    expect(result, isA<Success<PokemonDetail>>());
    expect((result as Success<PokemonDetail>).data.name, 'pikachu');
  });

  test('detail provider exposes repository failures', () async {
    final container = ProviderContainer(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(
          _FakeRepository(error: StateError('offline')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = pokemonDetailProvider('pikachu');
    await container.read(provider.notifier).load();

    final result = container.read(provider);
    expect(result, isA<Failure<PokemonDetail>>());
    expect((result as Failure<PokemonDetail>).message, contains('offline'));
  });
}

const _detail = PokemonDetail(
  id: 25,
  name: 'pikachu',
  imageUrl: 'pikachu.png',
  types: ['electric'],
  stats: [PokemonStat(name: 'speed', base: 90)],
  abilities: ['static'],
  heightM: 0.4,
  weightKg: 6.0,
);

class _FakeRepository extends PokemonRepository {
  final PokemonDetail? detail;
  final Object? error;

  _FakeRepository({this.detail, this.error})
      : super(client: PokeApiClient(), cache: PokemonCache());

  @override
  Future<(PokemonDetail detail, bool fromCache)> getPokemonDetail(
    String nameOrId,
  ) async {
    if (error != null) throw error!;
    return (detail!, true);
  }

  @override
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonPage({
    required int offset,
    required int limit,
  }) async {
    return (<PokemonSummary>[], true);
  }
}
