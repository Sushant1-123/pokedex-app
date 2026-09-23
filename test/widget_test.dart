//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';

void main() {
  testWidgets('renders the field pokedex shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_TestPokemonRepository()),
        ],
        child: const PokedexApp(),
      ),
    );
    await tester.pump();

    expect(find.text('POKÉDEX'), findsOneWidget);
    expect(find.text('SPECIMEN INDEX'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

class _TestPokemonRepository extends PokemonRepository {
  _TestPokemonRepository()
      : super(client: PokeApiClient(), cache: PokemonCache());

  @override
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonPage({
    required int offset,
    required int limit,
  }) async {
    return (
      [
        const PokemonSummary(
          id: 25,
          name: 'pikachu',
          imageUrl: 'https://example.com/pikachu.png',
          types: ['electric'],
        ),
      ],
      false,
    );
  }
}
