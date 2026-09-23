import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/result.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/data/models/pokemon_species.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/pokemon_detail_provider.dart';

import 'support/fakes.dart';

void main() {
  group('prev/next neighbours', () {
    final index = catalog(
      1025,
      extra: const [PokemonIndexEntry(id: 10034, name: 'charizard-mega-x')],
    );

    test('#1 has no previous, only a next', () {
      final n = neighboursOf(1, index);
      expect(n.previous, isNull);
      expect(n.next?.id, 2);
    });

    test('the last species has no next', () {
      final n = neighboursOf(1025, index);
      expect(n.previous?.id, 1024);
      expect(n.next, isNull);
    });

    test('a middle species has both, skipping forms', () {
      final n = neighboursOf(6, index);
      expect((n.previous?.id, n.next?.id), (5, 7));
    });

    test('alternate forms have no neighbours', () {
      final n = neighboursOf(10034, index);
      expect((n.previous, n.next), (null, null));
    });
  });

  group('detail provider', () {
    test('loads the record, then each section', () async {
      final container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakeRepository(index: catalog(10)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = pokemonDetailProvider(3);
      expect(container.read(provider), isA<Loading<PokemonDossier>>());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final dossier =
          (container.read(provider) as Success<PokemonDossier>).data;
      expect(dossier.detail.id, 3);
      expect(dossier.species, isA<Success<PokemonSpecies>>());
      expect(dossier.evolution, isA<Success<Object>>());
      expect(dossier.defenses, isA<Success<Object>>());
      expect(
        (dossier.neighbours.previous?.id, dossier.neighbours.next?.id),
        (2, 4),
      );
    });

    test('exposes repository failures', () async {
      final repository = FakeRepository()..failIds.add(3);
      final container = ProviderContainer(
        overrides: [pokemonRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final provider = pokemonDetailProvider(3);
      await container.read(provider.notifier).load();

      final result = container.read(provider);
      expect(result, isA<Failure<PokemonDossier>>());
      expect((result as Failure).message, contains('offline'));
    });

    test('marks a network result as not from cache', () async {
      final container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(FakeRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(pokemonDetailProvider(1).notifier).load();

      final result = container.read(pokemonDetailProvider(1));
      expect((result as Success).fromCache, isFalse);
    });
  });

  test('the animated sprite choice is remembered for the session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(animatedSpriteProvider), isFalse);
    container.read(animatedSpriteProvider.notifier).toggle();
    expect(container.read(animatedSpriteProvider), isTrue);
  });
}
