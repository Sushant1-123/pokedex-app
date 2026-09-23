import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/fetch_source.dart';
import 'package:pokedex_app/data/models/pokemon_species.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';

/// Uses a real Hive store in a temp directory with a controllable clock, and
/// a MockClient in place of the network.
void main() {
  late Directory dir;
  late DateTime now;
  late PokemonCache cache;
  late List<Uri> requests;
  late PokemonRepository repository;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pokedex_cache_test');
    Hive.init(dir.path);
    now = DateTime(2026, 1, 1, 12);
    cache = PokemonCache(clock: () => now);
    await cache.init();
    requests = [];
    repository = PokemonRepository(
      client: PokeApiClient(client: MockClient(_pokeApi(requests))),
      cache: cache,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  /// Calls [load] now, 59 minutes later (cached) and 61 minutes later
  /// (expired, refetched), checking the source and request count each time.
  Future<void> expectOneHourTtl(Future<FetchSource> Function() load) async {
    expect(await load(), isA<NetworkFetch>());
    final fetched = requests.length;

    now = now.add(const Duration(minutes: 59));
    expect(await load(), isA<CacheHit>());
    expect(requests, hasLength(fetched));

    now = now.add(const Duration(minutes: 2));
    expect(await load(), isA<NetworkFetch>());
    expect(requests, hasLength(fetched * 2));
  }

  test('the cache TTL is one hour', () {
    expect(AppConstants.cacheTtl, const Duration(hours: 1));
  });

  group('name index', () {
    test('is fetched with the full limit and parses ids from urls', () async {
      final (entries, _) = await repository.getPokemonIndex();

      expect(requests.single.path, '/api/v2/pokemon');
      expect(requests.single.queryParameters, {
        'limit': '100000',
        'offset': '0',
      });
      expect(entries.map((e) => (e.id, e.name)), [
        (1, 'bulbasaur'),
        (25, 'pikachu'),
        (10034, 'charizard-mega-x'),
      ]);
    });

    test('has a 1h TTL', () async {
      await expectOneHourTtl(
        () async => (await repository.getPokemonIndex()).$2,
      );
    });

    test('expired entries are evicted from the box', () async {
      await cache.write(CacheBox.nameIndex, PokemonRepository.catalogIndexKey, [
        {'id': 1, 'name': 'bulbasaur'},
      ]);

      now = now.add(const Duration(hours: 1, seconds: 1));
      expect(
        cache.read(CacheBox.nameIndex, PokemonRepository.catalogIndexKey),
        isNull,
      );

      // Even with the clock turned back, the entry is gone for good.
      now = now.subtract(const Duration(hours: 1));
      expect(
        cache.read(CacheBox.nameIndex, PokemonRepository.catalogIndexKey),
        isNull,
      );
    });
  });

  group('type data', () {
    test('holds members and damage relations from /type/{name}', () async {
      final (data, _) = await repository.getTypeData('fire');

      expect(requests.single.path, '/api/v2/type/fire');
      expect(data.members.map((e) => e.id), [4, 6, 10034]);
      expect(data.damage.doubleFrom, ['water']);
    });

    test('has a 1h TTL per type', () async {
      await expectOneHourTtl(
        () async => (await repository.getTypeData('fire')).$2,
      );
    });

    test('feeds the defensive matrix without another request', () async {
      await repository.getTypeData('fire');
      final (defenses, source) = await repository.getTypeDefenses(['fire']);

      expect(source, isA<CacheHit>());
      expect(defenses.weaknesses.single, (type: 'water', multiplier: 2.0));
      expect(requests, hasLength(1));
    });
  });

  group('species', () {
    test('is parsed from /pokemon-species/{id}', () async {
      final (species, _) = await repository.getSpecies(132);

      expect(requests.single.path, '/api/v2/pokemon-species/132');
      expect(species.genus, 'Transform Pokémon');
      expect(species.genderRatio, isA<Genderless>());
      expect(species.evolutionChainId, 66);
    });

    test('has a 1h TTL', () async {
      await expectOneHourTtl(() async => (await repository.getSpecies(132)).$2);
    });
  });

  group('evolution chain', () {
    test('is parsed from /evolution-chain/{id}', () async {
      final (chain, _) = await repository.getEvolutionChain(66);

      expect(requests.single.path, '/api/v2/evolution-chain/66');
      expect(chain.isSingleStage, isTrue);
      expect(chain.root.name, 'ditto');
    });

    test('has a 1h TTL', () async {
      await expectOneHourTtl(
        () async => (await repository.getEvolutionChain(66)).$2,
      );
    });
  });

  group('habitats', () {
    test('parse names and species from /pokemon-habitat', () async {
      final (names, _) = await repository.getHabitatNames();
      final (cave, _) = await repository.getHabitat('cave');

      expect(names, ['cave', 'forest']);
      expect(cave.species.map((s) => (s.id, s.name)), [
        (41, 'zubat'),
        (74, 'geodude'),
      ]);
    });

    test('have a 1h TTL', () async {
      await expectOneHourTtl(
        () async => (await repository.getHabitatNames()).$2,
      );
      requests.clear();
      await expectOneHourTtl(
        () async => (await repository.getHabitat('cave')).$2,
      );
    });
  });

  group('abilities', () {
    test('the list parses ids from urls', () async {
      final (abilities, _) = await repository.getAbilityIndex();

      expect(requests.single.queryParameters['limit'], '100000');
      expect(abilities, [(id: 1, name: 'stench'), (id: 65, name: 'overgrow')]);
    });

    test('details parse effects, generation and hidden holders', () async {
      final (overgrow, _) = await repository.getAbility('overgrow');

      expect(overgrow.shortEffect, 'Strengthens grass moves at low HP.');
      expect(overgrow.effect, contains('1.5'));
      expect(overgrow.generation, 'III');
      expect(overgrow.pokemon.map((p) => (p.pokemon.name, p.isHidden)), [
        ('bulbasaur', false),
        ('pansage', true),
      ]);
    });

    test('list and detail have a 1h TTL', () async {
      await expectOneHourTtl(
        () async => (await repository.getAbilityIndex()).$2,
      );
      requests.clear();
      await expectOneHourTtl(
        () async => (await repository.getAbility('overgrow')).$2,
      );
    });
  });

  group('pokemon detail', () {
    test('has a 1h TTL and survives the cache round trip', () async {
      await expectOneHourTtl(
        () async => (await repository.getPokemonDetail(1)).$2,
      );
      final (detail, _) = await repository.getPokemonDetail(1);
      expect(detail.types, ['grass']);
      expect(detail.cryUrl, 'https://raw.githubusercontent.com/cries/1.ogg');
    });

    test('summaries are built from the detail cache', () async {
      final (index, _) = await repository.getPokemonIndex();
      await repository.getPokemonDetail(1);
      final fetched = requests.length;

      final (items, source) = await repository.getPokemonSummaries([
        index.first,
      ]);
      expect(source, isA<CacheHit>());
      expect(items.single.stats.single.base, 45);
      expect(requests, hasLength(fetched));
    });
  });
}

/// A tiny stand-in for pokeapi.co covering the endpoints under test.
MockClientHandler _pokeApi(List<Uri> requests) {
  const base = 'https://pokeapi.co/api/v2';
  Map<String, dynamic> resource(String kind, String name, int id) => {
    'name': name,
    'url': '$base/$kind/$id/',
  };
  Map<String, dynamic> english(String key, String value) => {
    key: value,
    'language': resource('language', 'en', 9),
  };

  return (http.Request request) async {
    requests.add(request.url);
    final Object? body = switch (request.url.path) {
      '/api/v2/pokemon' => {
        'count': 3,
        'results': [
          resource('pokemon', 'bulbasaur', 1),
          resource('pokemon', 'pikachu', 25),
          resource('pokemon', 'charizard-mega-x', 10034),
        ],
      },
      '/api/v2/pokemon/1' => {
        'id': 1,
        'name': 'bulbasaur',
        'height': 7,
        'weight': 69,
        'species': resource('pokemon-species', 'bulbasaur', 1),
        'cries': {'latest': 'https://raw.githubusercontent.com/cries/1.ogg'},
        'types': [
          {'type': resource('type', 'grass', 12)},
        ],
        'stats': [
          {'stat': resource('stat', 'hp', 1), 'base_stat': 45},
        ],
        'abilities': <Object>[],
      },
      '/api/v2/type/fire' => {
        'name': 'fire',
        'pokemon': [
          {'slot': 1, 'pokemon': resource('pokemon', 'charizard', 6)},
          {'slot': 1, 'pokemon': resource('pokemon', 'charmander', 4)},
          {
            'slot': 1,
            'pokemon': resource('pokemon', 'charizard-mega-x', 10034),
          },
        ],
        'damage_relations': {
          'double_damage_from': [resource('type', 'water', 11)],
          'half_damage_from': <Object>[],
          'no_damage_from': <Object>[],
        },
      },
      '/api/v2/pokemon-species/132' => {
        'id': 132,
        'name': 'ditto',
        'gender_rate': -1,
        'genera': [english('genus', 'Transform Pokémon')],
        'flavor_text_entries': [
          english('flavor_text', 'It can transform into anything.'),
        ],
        'evolution_chain': {'url': '$base/evolution-chain/66/'},
        'generation': resource('generation', 'generation-i', 1),
        'growth_rate': resource('growth-rate', 'medium', 2),
        'is_legendary': false,
        'is_mythical': false,
      },
      '/api/v2/evolution-chain/66' => {
        'id': 66,
        'chain': {
          'species': resource('pokemon-species', 'ditto', 132),
          'evolution_details': <Object>[],
          'evolves_to': <Object>[],
        },
      },
      '/api/v2/pokemon-habitat' => {
        'count': 2,
        'results': [
          resource('pokemon-habitat', 'cave', 1),
          resource('pokemon-habitat', 'forest', 2),
        ],
      },
      '/api/v2/pokemon-habitat/cave' => {
        'id': 1,
        'name': 'cave',
        'pokemon_species': [
          resource('pokemon-species', 'geodude', 74),
          resource('pokemon-species', 'zubat', 41),
        ],
      },
      '/api/v2/ability' => {
        'count': 2,
        'results': [
          resource('ability', 'stench', 1),
          resource('ability', 'overgrow', 65),
        ],
      },
      '/api/v2/ability/overgrow' => {
        'id': 65,
        'name': 'overgrow',
        'generation': resource('generation', 'generation-iii', 3),
        'effect_entries': [
          {
            'effect': 'Grass moves do 1.5x damage at 1/3 HP or less.',
            'short_effect': 'Strengthens grass moves at low HP.',
            'language': resource('language', 'en', 9),
          },
        ],
        'flavor_text_entries': <Object>[],
        'pokemon': [
          {'is_hidden': false, 'pokemon': resource('pokemon', 'bulbasaur', 1)},
          {'is_hidden': true, 'pokemon': resource('pokemon', 'pansage', 511)},
        ],
      },
      _ => null,
    };
    return body == null
        ? http.Response('Not found', 404)
        : http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
  };
}
