import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/presentation/providers/pokemon_list_provider.dart';
import 'package:pokedex_app/presentation/screens/pokemon_list_screen.dart';
import 'package:pokedex_app/presentation/widgets/pagination_bar.dart';

void main() {
  const index = [
    PokemonIndexEntry(id: 1, name: 'bulbasaur'),
    PokemonIndexEntry(id: 6, name: 'charizard'),
    PokemonIndexEntry(id: 25, name: 'pikachu'),
    PokemonIndexEntry(id: 1009, name: 'walking-wake'),
    PokemonIndexEntry(id: 10034, name: 'charizard-mega-x'),
    PokemonIndexEntry(id: 10080, name: 'pikachu-rock-star'),
  ];

  group('base species vs forms', () {
    test('the directory (no query) lists only ids below 10000', () {
      expect(searchPokemonIndex(index, '').map((e) => e.id), [1, 6, 25, 1009]);
      expect(
        const PokemonIndexEntry(id: 9999, name: 'x').isBaseSpecies,
        isTrue,
      );
      expect(
        const PokemonIndexEntry(
          id: AppConstants.formIdStart + 1,
          name: 'x',
        ).isBaseSpecies,
        isFalse,
      );
    });

    test('search also finds alternate forms', () {
      expect(searchPokemonIndex(index, 'charizard').map((e) => e.id), [
        6,
        10034,
      ]);
    });
  });

  group('name index search', () {
    test('is case-insensitive and trims the query', () {
      expect(searchPokemonIndex(index, '  PIKA ').map((e) => e.name), [
        'pikachu',
        'pikachu-rock-star',
      ]);
    });

    test('matches an exact id, with or without # and zeros', () {
      expect(searchPokemonIndex(index, '25').single.name, 'pikachu');
      expect(searchPokemonIndex(index, '#0025').single.name, 'pikachu');
    });

    test('returns nothing for an unmatched query', () {
      expect(searchPokemonIndex(index, 'missingno'), isEmpty);
    });
  });

  group('page counts', () {
    test('uses 30 cards per page', () {
      expect(AppConstants.pageSize, 30);
      expect(pageCountFor(1025), 35);
      expect(pageCountFor(30), 1);
      expect(pageCountFor(31), 2);
      expect(pageCountFor(0), 1);
    });

    test('the pager shows first, last and a window around the page', () {
      expect(pageWindow(1, 35), [1, 2, 3, null, 35]);
      expect(pageWindow(4, 35), [1, 2, 3, 4, 5, null, 35]);
      expect(pageWindow(18, 35), [1, null, 17, 18, 19, null, 35]);
      expect(pageWindow(35, 35), [1, null, 33, 34, 35]);
      expect(pageWindow(1, 2), [1, 2]);
      expect(pageWindow(1, 1), [1]);
    });

    test('the specimen counter is formatted with separators', () {
      expect(formatCount(1025), '1,025');
      expect(formatCount(30), '30');
    });
  });

  test('a whitespace-only query does not count as a filter', () {
    const blank = PokemonListState(status: ListInitialLoading(), query: '  ');
    const typed = PokemonListState(
      status: ListInitialLoading(),
      selectedType: 'fire',
    );

    expect(blank.isFiltered, isFalse);
    expect(typed.isFiltered, isTrue);
  });
}
