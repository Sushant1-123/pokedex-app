import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';

void main() {
  const ids = [1, 4, 5, 6, 7, 25, 150];

  test(
    'uses the canonical HTTPS official artwork URL for every requested ID',
    () {
      for (final id in ids) {
        expect(
          pokemonArtworkUrl(id),
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
        );
      }
    },
  );

  test('model parsers keep cached and API image URLs canonical', () {
    for (final id in ids) {
      final detail = PokemonDetail.fromJson(_detailJson(id));
      expect(detail.imageUrl, pokemonArtworkUrl(id));
      expect(
        PokemonDetail.fromCacheJson(detail.toCacheJson()).imageUrl,
        pokemonArtworkUrl(id),
      );

      final summary = detail.toSummary();
      expect(summary.imageUrl, pokemonArtworkUrl(id));
      expect(
        PokemonSummary.fromCacheJson(summary.toCacheJson()).imageUrl,
        pokemonArtworkUrl(id),
      );
    }
  });
}

Map<String, dynamic> _summaryJson(int id) => {
  'id': id,
  'name': 'pokemon-$id',
  'types': [
    {
      'type': {'name': 'normal'},
    },
  ],
};

Map<String, dynamic> _detailJson(int id) => {
  ..._summaryJson(id),
  'height': 10,
  'weight': 100,
  'stats': [
    {
      'stat': {'name': 'hp'},
      'base_stat': 50,
    },
  ],
  'abilities': [
    {
      'ability': {'name': 'run-away'},
    },
  ],
};
