import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/presentation/providers/pokemon_list_provider.dart';

void main() {
  const items = [
    PokemonSummary(
      id: 1,
      name: 'bulbasaur',
      imageUrl: 'bulbasaur.png',
      types: ['grass', 'poison'],
    ),
    PokemonSummary(
      id: 4,
      name: 'charmander',
      imageUrl: 'charmander.png',
      types: ['fire'],
    ),
  ];

  test('filters summaries by name', () {
    const state = PokemonListState(status: ListInitialLoading(), query: 'saur');

    expect(state.visible(items).map((pokemon) => pokemon.name), ['bulbasaur']);
  });

  test('filters summaries by type and query together', () {
    const state = PokemonListState(
      status: ListInitialLoading(),
      query: 'char',
      selectedType: 'fire',
    );

    expect(state.visible(items).map((pokemon) => pokemon.name), ['charmander']);
  });

  test('returns no summaries for an unmatched query', () {
    const state = PokemonListState(
      status: ListInitialLoading(),
      query: 'missing',
    );

    expect(state.visible(items), isEmpty);
  });
}
