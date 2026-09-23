import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
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

  group('name index', () {
    test(
      'is fetched once with the full limit and parses ids from urls',
      () async {
        final (entries, fromCache) = await repository.getPokemonIndex();

        expect(fromCache, isFalse);
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
      },
    );

    test('is served from Hive for up to an hour, then refetched', () async {
      await repository.getPokemonIndex();

      now = now.add(const Duration(minutes: 59));
      final (cached, fromCache) = await repository.getPokemonIndex();
      expect(fromCache, isTrue);
      expect(cached, hasLength(3));
      expect(requests, hasLength(1));

      now = now.add(const Duration(minutes: 2));
      final (_, refetched) = await repository.getPokemonIndex();
      expect(refetched, isFalse);
      expect(requests, hasLength(2));
    });

    test('expired entries are evicted from the box', () async {
      await cache.writeIndex(PokemonRepository.catalogIndexKey, [
        {'id': 1, 'name': 'bulbasaur'},
      ]);

      now = now.add(const Duration(hours: 1, seconds: 1));
      expect(cache.readIndex(PokemonRepository.catalogIndexKey), isNull);

      // Even with the clock turned back, the entry is gone for good.
      now = now.subtract(const Duration(hours: 1));
      expect(cache.readIndex(PokemonRepository.catalogIndexKey), isNull);
    });
  });

  group('type members', () {
    test('come from /type/{name}, sorted by id', () async {
      final (entries, _) = await repository.getTypeMembers('fire');

      expect(requests.single.path, '/api/v2/type/fire');
      expect(entries.map((e) => e.id), [4, 6, 10034]);
    });

    test('are cached per type for one hour', () async {
      await repository.getTypeMembers('fire');

      now = now.add(const Duration(minutes: 30));
      final (_, fromCache) = await repository.getTypeMembers('fire');
      expect(fromCache, isTrue);
      expect(requests, hasLength(1));

      now = now.add(const Duration(minutes: 31));
      final (_, refetched) = await repository.getTypeMembers('fire');
      expect(refetched, isFalse);
      expect(requests, hasLength(2));
    });
  });

  test('a catalog page also caches each full record', () async {
    final (page, _) = await repository.getPokemonPage(offset: 0, limit: 1);
    expect(page.single.name, 'bulbasaur');
    final pageRequests = requests.length;

    final (detail, fromCache) = await repository.getPokemonDetail('bulbasaur');
    expect(fromCache, isTrue);
    expect(detail.types, ['grass']);
    expect(requests, hasLength(pageRequests));
  });
}

/// A tiny stand-in for pokeapi.co covering the endpoints under test.
MockClientHandler _pokeApi(List<Uri> requests) {
  const base = 'https://pokeapi.co/api/v2';
  Map<String, dynamic> resource(String kind, String name, int id) => {
    'name': name,
    'url': '$base/$kind/$id/',
  };

  return (http.Request request) async {
    requests.add(request.url);
    final path = request.url.path;
    final Object? body = switch (path) {
      '/api/v2/pokemon' when request.url.queryParameters['limit'] == '100000' =>
        {
          'count': 3,
          'results': [
            resource('pokemon', 'bulbasaur', 1),
            resource('pokemon', 'pikachu', 25),
            resource('pokemon', 'charizard-mega-x', 10034),
          ],
        },
      '/api/v2/pokemon' => {
        'results': [resource('pokemon', 'bulbasaur', 1)],
      },
      '/api/v2/pokemon/1/' => {
        'id': 1,
        'name': 'bulbasaur',
        'height': 7,
        'weight': 69,
        'types': [
          {
            'type': {'name': 'grass'},
          },
        ],
        'stats': <Object>[],
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
      },
      _ => null,
    };
    return body == null
        ? http.Response('Not found', 404)
        : http.Response(jsonEncode(body), 200);
  };
}
