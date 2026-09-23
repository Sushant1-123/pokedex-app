import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/presentation/providers/pokemon_list_provider.dart';

void main() {
  const index = [
    PokemonIndexEntry(id: 1, name: 'bulbasaur'),
    PokemonIndexEntry(id: 4, name: 'charmander'),
    PokemonIndexEntry(id: 25, name: 'pikachu'),
    PokemonIndexEntry(id: 1009, name: 'walking-wake'),
  ];

  test('searches the name index case-insensitively', () {
    expect(searchPokemonIndex(index, 'SAUR').map((e) => e.name), ['bulbasaur']);
    expect(searchPokemonIndex(index, '  Wake ').map((e) => e.id), [1009]);
  });

  test('returns no index entries for an unmatched query', () {
    expect(searchPokemonIndex(index, 'missing'), isEmpty);
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
