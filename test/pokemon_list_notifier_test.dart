import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/models/fetch_source.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/pokemon_list_provider.dart';

import 'support/fakes.dart';

const _named = [
  PokemonIndexEntry(id: 4, name: 'charmander'),
  PokemonIndexEntry(id: 5, name: 'charmeleon'),
  PokemonIndexEntry(id: 6, name: 'charizard'),
  PokemonIndexEntry(id: 25, name: 'pikachu'),
  PokemonIndexEntry(id: 146, name: 'moltres'),
  PokemonIndexEntry(id: 736, name: 'charjabug'),
  PokemonIndexEntry(id: 1009, name: 'walking-wake'),
  PokemonIndexEntry(id: 10034, name: 'charizard-mega-x'),
];

void main() {
  late FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeRepository(
      index: catalog(1025, extra: _named),
      typeMembers: {
        'fire': [4, 5, 6, 146, 10034],
      },
    );
    container = ProviderContainer(
      overrides: [pokemonRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  PokemonListNotifier notifier() =>
      container.read(pokemonListProvider.notifier);
  PokemonListStatus status() => container.read(pokemonListProvider).status;
  List<String> names() =>
      (status() as ListLoaded).items.map((p) => p.name).toList();

  Future<void> started() async {
    container.read(pokemonListProvider);
    await _settle();
  }

  group('numbered pagination', () {
    test('page 1 has 30 base species and the right page count', () async {
      await started();

      final page = status() as ListLoaded;
      expect(page.page, 1);
      expect(page.items, hasLength(AppConstants.pageSize));
      expect(page.items.first.id, 1);
      expect(page.totalCount, 1025);
      expect(page.pageCount, 35);
    });

    test('changing page replaces the items with that slice', () async {
      await started();

      await notifier().goToPage(35);

      final last = status() as ListLoaded;
      expect(last.page, 35);
      // 1025 = 34 full pages + 5; the forms (id >= 10000) are not listed.
      expect(last.items.map((p) => p.id), [1021, 1022, 1023, 1024, 1025]);
    });

    test('shows page-loading while a page is in flight', () async {
      await started();
      repository.hold(31);

      final loading = notifier().goToPage(2);
      await _settle();
      expect(status(), isA<ListPageLoading>());
      expect((status() as ListPaged).page, 2);

      repository.release(31);
      await loading;
      expect((status() as ListLoaded).items.first.id, 31);
    });

    test('ignores out-of-range pages and the current page', () async {
      await started();
      final requests = repository.detailRequests.length;

      await notifier().goToPage(0);
      await notifier().goToPage(36);
      await notifier().goToPage(1);

      expect(repository.detailRequests, hasLength(requests));
    });

    test('a failed page keeps the pager and can be retried', () async {
      await started();
      repository.failIds.add(31);

      await notifier().goToPage(2);
      final failed = status() as ListPageFailure;
      expect(failed.page, 2);
      expect(failed.pageCount, 35);
      expect(failed.message, contains('offline'));

      repository.failIds.clear();
      await notifier().retryPage();
      expect((status() as ListLoaded).page, 2);
    });

    test('a quick second page change wins over a slow first one', () async {
      await started();
      repository.hold(31);

      final slow = notifier().goToPage(2);
      await _settle();
      await notifier().goToPage(3);
      repository.release(31);
      await slow;

      expect((status() as ListLoaded).page, 3);
      expect((status() as ListLoaded).items.first.id, 61);
    });

    test('reports the real latency of the last load', () async {
      await started();

      final source = container.read(pokemonListProvider).lastSource;
      expect(source, isA<NetworkFetch>());
      expect(
        (source as NetworkFetch).latency,
        const Duration(milliseconds: 42),
      );
    });
  });

  group('search', () {
    test('searches the full index, forms included', () async {
      await started();

      notifier().setQuery('charizard');
      await _afterDebounce();

      expect(names(), ['charizard', 'charizard-mega-x']);
    });

    test('search results are paginated too', () async {
      await started();

      notifier().setQuery('pokemon-1');
      await _afterDebounce();

      final first = status() as ListLoaded;
      // pokemon-1, -10..19, -100..199 and -1000..1025, minus #146 and
      // #1009 which have real names in this index.
      expect(first.totalCount, 1 + 10 + 100 + 26 - 2);
      expect(first.pageCount, 5);
      expect(first.items, hasLength(AppConstants.pageSize));

      await notifier().goToPage(5);
      expect((status() as ListLoaded).items, hasLength(135 - 4 * 30));
    });

    test('debounces typing into a single search', () async {
      await started();
      final before = repository.indexRequests;

      notifier().setQuery('c');
      notifier().setQuery('ch');
      notifier().setQuery('char');
      await _afterDebounce();

      expect(repository.indexRequests, before + 1);
      expect(names(), containsAll(['charmander', 'charjabug']));
    });

    test('ignores a stale response that arrives after a newer one', () async {
      await started();
      repository
        ..hold(6)
        ..hold(25);

      notifier().setQuery('charizard');
      await _afterDebounce();
      notifier().setQuery('pikachu');
      await _afterDebounce();

      // The newer search resolves first, then the older one straggles in.
      repository.release(25);
      await _settle();
      repository.release(6);
      await _settle();

      expect(names(), ['pikachu']);
      expect(container.read(pokemonListProvider).query, 'pikachu');
    });

    test('shows the empty state when nothing matches', () async {
      await started();

      notifier().setQuery('missingno');
      await _afterDebounce();

      expect(status(), isA<ListEmpty>());
    });

    test(
      'clearing the query restores the catalog page without refetching',
      () async {
        await started();
        await notifier().goToPage(3);
        final catalog = status() as ListLoaded;

        notifier().setQuery('pika');
        await _afterDebounce();
        final requests = repository.detailRequests.length;
        notifier().setQuery('');
        await _settle();

        expect(status(), same(catalog));
        expect(repository.detailRequests, hasLength(requests));
      },
    );
  });

  group('type filter', () {
    test('lists the base-species members of the type from /type', () async {
      await started();

      notifier().setType('fire');
      await _settle();

      expect(repository.typeRequests, ['fire']);
      expect(names(), ['charmander', 'charmeleon', 'charizard', 'moltres']);
      expect((status() as ListLoaded).pageCount, 1);
    });

    test('intersects the type members with the search query', () async {
      await started();

      notifier().setType('fire');
      await _settle();
      notifier().setQuery('char');
      await _afterDebounce();

      // charjabug matches "char" but is not fire; moltres is fire but does
      // not match. The fire mega form matches both, so search shows it.
      expect(names(), [
        'charmander',
        'charmeleon',
        'charizard',
        'charizard-mega-x',
      ]);
    });

    test('clearFilters returns to the first catalog page', () async {
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
      expect((state.status as ListLoaded).items.first.id, 1);
    });
  });
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

Future<void> _afterDebounce() => Future<void>.delayed(
  AppConstants.searchDebounce + const Duration(milliseconds: 50),
);
