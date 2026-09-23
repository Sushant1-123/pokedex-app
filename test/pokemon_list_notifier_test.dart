import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/pokemon_list_provider.dart';

void main() {
  late _FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeRepository();
    container = ProviderContainer(
      overrides: [pokemonRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  PokemonListNotifier notifier() =>
      container.read(pokemonListProvider.notifier);
  PokemonListStatus status() => container.read(pokemonListProvider).status;

  Future<void> started() async {
    container.read(pokemonListProvider);
    await _settle();
  }

  group('pagination', () {
    test('loads the first page, then appends the next one', () async {
      await started();

      final first = status() as ListLoaded;
      expect(first.items, hasLength(AppConstants.pageSize));
      expect(first.hasMore, isTrue);

      await notifier().loadMore();

      final second = status() as ListLoaded;
      expect(second.items, hasLength(AppConstants.pageSize * 2));
      expect(second.items.map((p) => p.id), [
        for (var id = 1; id <= AppConstants.pageSize * 2; id++) id,
      ]);
      expect(repository.pageOffsets, [0, AppConstants.pageSize]);
    });

    test('shows loading-more while the next page is in flight', () async {
      await started();
      final pending = Completer<void>();
      repository.pageGate = pending;

      final loading = notifier().loadMore();
      expect(status(), isA<ListLoadingMore>());

      pending.complete();
      await loading;
      expect(status(), isA<ListLoaded>());
    });

    test('stops when a short page arrives', () async {
      repository.catalogSize = AppConstants.pageSize + 5;
      await started();
      await notifier().loadMore();

      final loaded = status() as ListLoaded;
      expect(loaded.items, hasLength(AppConstants.pageSize + 5));
      expect(loaded.hasMore, isFalse);

      await notifier().loadMore();
      expect(repository.pageOffsets, hasLength(2));
    });

    test('keeps loaded items and offers a retry when a page fails', () async {
      await started();
      repository.failNextPage = true;

      await notifier().loadMore();

      final failed = status() as ListLoaded;
      expect(failed.items, hasLength(AppConstants.pageSize));
      expect(failed.loadMoreError, contains('offline'));

      await notifier().loadMore();
      final retried = status() as ListLoaded;
      expect(retried.items, hasLength(AppConstants.pageSize * 2));
      expect(retried.loadMoreError, isNull);
    });
  });

  group('search', () {
    test('searches the full name index, beyond the loaded pages', () async {
      await started();

      notifier().setQuery('wake');
      await _afterDebounce();

      final loaded = status() as ListLoaded;
      expect(loaded.items.map((p) => p.name), ['walking-wake']);
      expect(loaded.hasMore, isFalse);
    });

    test('debounces typing into a single search', () async {
      await started();

      notifier().setQuery('c');
      notifier().setQuery('ch');
      notifier().setQuery('char');
      await _afterDebounce();

      expect(repository.indexRequests, 1);
      expect(
        (status() as ListLoaded).items.map((p) => p.name),
        containsAll(['charmander', 'charjabug']),
      );
    });

    test('ignores a stale response that arrives after a newer one', () async {
      await started();
      repository.holdSummaries = true;

      notifier().setQuery('bulba');
      await _afterDebounce();
      notifier().setQuery('pika');
      await _afterDebounce();

      // The newer search resolves first, then the older one straggles in.
      repository.releaseSummaries('pikachu');
      await _settle();
      repository.releaseSummaries('bulbasaur');
      await _settle();

      final loaded = status() as ListLoaded;
      expect(loaded.items.map((p) => p.name), ['pikachu']);
      expect(container.read(pokemonListProvider).query, 'pika');
    });

    test('shows the empty state when nothing matches', () async {
      await started();

      notifier().setQuery('missingno');
      await _afterDebounce();

      expect(status(), isA<ListEmpty>());
    });

    test(
      'clearing the query restores the catalog without refetching',
      () async {
        await started();
        await notifier().loadMore();
        final catalog = status() as ListLoaded;

        notifier().setQuery('pika');
        await _afterDebounce();
        notifier().setQuery('');
        await _settle();

        final restored = status() as ListLoaded;
        expect(restored.items, same(catalog.items));
        expect(repository.pageOffsets, [0, AppConstants.pageSize]);
      },
    );

    test('pages through search matches on scroll', () async {
      repository.extraIndex = [
        for (var i = 0; i < 45; i++)
          PokemonIndexEntry(id: 2000 + i, name: 'testmon-$i'),
      ];
      await started();

      notifier().setQuery('testmon');
      await _afterDebounce();
      expect((status() as ListLoaded).items, hasLength(AppConstants.pageSize));

      await notifier().loadMore();
      final loaded = status() as ListLoaded;
      expect(loaded.items, hasLength(45));
      expect(loaded.hasMore, isFalse);
    });
  });

  group('type filter', () {
    test('lists every member of the type from /type', () async {
      await started();

      notifier().setType('fire');
      await _settle();

      expect(repository.typeRequests, ['fire']);
      expect((status() as ListLoaded).items.map((p) => p.name), [
        'charmander',
        'charmeleon',
        'charizard',
        'moltres',
      ]);
    });

    test('intersects the type members with the search query', () async {
      await started();

      notifier().setType('fire');
      await _settle();
      notifier().setQuery('char');
      await _afterDebounce();

      // charjabug matches "char" but is not fire; moltres is fire but does
      // not match "char".
      expect((status() as ListLoaded).items.map((p) => p.name), [
        'charmander',
        'charmeleon',
        'charizard',
      ]);
    });

    test('clearFilters returns to the catalog', () async {
      await started();
      notifier().setType('fire');
      await _settle();
      notifier().setQuery('zzz');
      await _afterDebounce();
      expect(status(), isA<ListEmpty>());

      notifier().clearFilters();
      await _settle();

      final state = container.read(pokemonListProvider);
      expect(state.query, isEmpty);
      expect(state.selectedType, isNull);
      expect((state.status as ListLoaded).items.first.name, 'pokemon-1');
    });
  });
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

Future<void> _afterDebounce() => Future<void>.delayed(
  AppConstants.searchDebounce + const Duration(milliseconds: 50),
);

const _named = [
  PokemonIndexEntry(id: 1, name: 'bulbasaur'),
  PokemonIndexEntry(id: 4, name: 'charmander'),
  PokemonIndexEntry(id: 5, name: 'charmeleon'),
  PokemonIndexEntry(id: 6, name: 'charizard'),
  PokemonIndexEntry(id: 25, name: 'pikachu'),
  PokemonIndexEntry(id: 146, name: 'moltres'),
  PokemonIndexEntry(id: 736, name: 'charjabug'),
  PokemonIndexEntry(id: 1009, name: 'walking-wake'),
];

const _fire = [4, 5, 6, 146];

/// In-memory repository: a numbered catalog for paging plus a small named
/// index for search and type filtering. Never touches network or Hive.
class _FakeRepository extends PokemonRepository {
  _FakeRepository() : super(client: PokeApiClient(), cache: PokemonCache());

  int catalogSize = 1000;
  List<PokemonIndexEntry> extraIndex = [];
  final pageOffsets = <int>[];
  final typeRequests = <String>[];
  int indexRequests = 0;
  bool failNextPage = false;
  Completer<void>? pageGate;

  bool holdSummaries = false;
  final _heldSummaries = <String, Completer<void>>{};

  /// Lets a held getPokemonSummaries call whose first match is [name] finish.
  void releaseSummaries(String name) => _heldSummaries[name]!.complete();

  @override
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonPage({
    required int offset,
    required int limit,
  }) async {
    pageOffsets.add(offset);
    await pageGate?.future;
    if (failNextPage) {
      failNextPage = false;
      throw PokeApiException('offline');
    }
    final end = (offset + limit).clamp(0, catalogSize);
    return (
      [
        for (var id = offset + 1; id <= end; id++)
          _summary(PokemonIndexEntry(id: id, name: 'pokemon-$id')),
      ],
      false,
    );
  }

  @override
  Future<(List<PokemonIndexEntry> entries, bool fromCache)>
  getPokemonIndex() async {
    indexRequests++;
    return ([..._named, ...extraIndex], true);
  }

  @override
  Future<(List<PokemonIndexEntry> entries, bool fromCache)> getTypeMembers(
    String type,
  ) async {
    typeRequests.add(type);
    final members = type == 'fire' ? _fire : const <int>[];
    return (_named.where((e) => members.contains(e.id)).toList(), true);
  }

  @override
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonSummaries(
    List<PokemonIndexEntry> entries,
  ) async {
    if (holdSummaries && entries.isNotEmpty) {
      final gate = Completer<void>();
      _heldSummaries[entries.first.name] = gate;
      await gate.future;
    }
    return (entries.map(_summary).toList(), true);
  }

  PokemonSummary _summary(PokemonIndexEntry entry) => PokemonSummary(
    id: entry.id,
    name: entry.name,
    imageUrl: pokemonArtworkUrl(entry.id),
    types: _fire.contains(entry.id) ? const ['fire'] : const ['normal'],
  );
}
