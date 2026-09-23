import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/data/models/evolution_chain.dart';
import 'package:pokedex_app/data/models/fetch_source.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/models/pokemon_species.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/models/pokemon_type_data.dart';
import 'package:pokedex_app/data/models/type_defenses.dart';

Map<String, dynamic> _named(String name, String url) => {
  'name': name,
  'url': url,
};

Map<String, dynamic> _lang(String code) =>
    _named(code, 'https://pokeapi.co/api/v2/language/1/');

Map<String, dynamic> _speciesJson({int genderRate = 1}) => {
  'id': 6,
  'name': 'charizard',
  'gender_rate': genderRate,
  'is_legendary': false,
  'is_mythical': false,
  'genera': [
    {'genus': 'Flamme-Pokémon', 'language': _lang('de')},
    {'genus': 'Flame Pokémon', 'language': _lang('en')},
  ],
  'flavor_text_entries': [
    {
      'flavor_text': 'Spits fire that\nis hot enough to\nmelt boulders.',
      'language': _lang('en'),
    },
    {'flavor_text': 'Crache du feu.', 'language': _lang('fr')},
    {
      'flavor_text':
          'Its wings can carry this Pokémon close to an\naltitude of '
          '4,600 feet.\u000cIt blows out fire.',
      'language': _lang('en'),
    },
  ],
  'evolution_chain': {'url': 'https://pokeapi.co/api/v2/evolution-chain/2/'},
  'generation': _named(
    'generation-i',
    'https://pokeapi.co/api/v2/generation/1/',
  ),
  'growth_rate': _named(
    'medium-slow',
    'https://pokeapi.co/api/v2/growth-rate/4/',
  ),
};

Map<String, dynamic> _stageJson(
  String name,
  int id,
  List<Map<String, dynamic>> details, [
  List<Map<String, dynamic>> next = const [],
]) => {
  'species': _named(name, 'https://pokeapi.co/api/v2/pokemon-species/$id/'),
  'evolution_details': details,
  'evolves_to': next,
};

Map<String, dynamic> _detail(
  String trigger, {
  int? minLevel,
  String? item,
  int? minHappiness,
  String timeOfDay = '',
}) => {
  'trigger': _named(trigger, 'https://pokeapi.co/api/v2/evolution-trigger/1/'),
  'min_level': minLevel,
  'item': item == null ? null : _named(item, 'https://pokeapi.co/item/1/'),
  'min_happiness': minHappiness,
  'held_item': null,
  'time_of_day': timeOfDay,
};

void main() {
  group('species parsing', () {
    test('reads the English genus, generation and chain id', () {
      final species = PokemonSpecies.fromJson(_speciesJson());

      expect(species.genus, 'Flame Pokémon');
      expect(species.generation, 'I');
      expect(species.growthRate, 'medium-slow');
      expect(species.evolutionChainId, 2);
    });

    test('uses the newest English flavor text, without line breaks', () {
      final species = PokemonSpecies.fromJson(_speciesJson());

      expect(
        species.flavorText,
        'Its wings can carry this Pokémon close to an altitude of 4,600 '
        'feet. It blows out fire.',
      );
    });

    test('turns gender_rate into a male/female split', () {
      final ratio = PokemonSpecies.fromJson(_speciesJson()).genderRatio;

      expect(ratio, isA<Gendered>());
      expect((ratio as Gendered).malePercent, 87.5);
      expect(ratio.femalePercent, 12.5);
    });

    test('gender_rate -1 means genderless', () {
      final species = PokemonSpecies.fromJson(_speciesJson(genderRate: -1));

      expect(species.genderRatio, isA<Genderless>());
    });

    test('survives a cache round trip', () {
      final species = PokemonSpecies.fromJson(_speciesJson(genderRate: -1));
      final cached = PokemonSpecies.fromCacheJson(species.toCacheJson());

      expect(cached.genus, species.genus);
      expect(cached.flavorText, species.flavorText);
      expect(cached.genderRatio, isA<Genderless>());
      expect(cached.evolutionChainId, 2);
    });
  });

  group('evolution chain parsing', () {
    test('a linear chain keeps its level triggers', () {
      final chain = EvolutionChain.fromJson({
        'id': 2,
        'chain': _stageJson('charmander', 4, [], [
          _stageJson(
            'charmeleon',
            5,
            [_detail('level-up', minLevel: 16)],
            [
              _stageJson('charizard', 6, [_detail('level-up', minLevel: 36)]),
            ],
          ),
        ]),
      });

      expect(chain.isSingleStage, isFalse);
      expect(chain.stages.map((s) => s.map((e) => e.name).toList()), [
        ['charmander'],
        ['charmeleon'],
        ['charizard'],
      ]);
      expect(chain.root.trigger, isNull);
      expect(chain.stages[1].single.trigger, isA<LevelUp>());
      expect((chain.stages[2].single.trigger as LevelUp).level, 36);
      expect(chain.stages[2].single.speciesId, 6);
    });

    test('a branching chain keeps every branch and its own trigger', () {
      final chain = EvolutionChain.fromJson({
        'id': 67,
        'chain': _stageJson('eevee', 133, [], [
          _stageJson('vaporeon', 134, [
            _detail('use-item', item: 'water-stone'),
          ]),
          _stageJson('espeon', 196, [
            _detail('level-up', minHappiness: 160, timeOfDay: 'day'),
          ]),
          // Leafeon lists location-based level-ups first; the item wins.
          _stageJson('leafeon', 470, [
            _detail('level-up'),
            _detail('use-item', item: 'leaf-stone'),
          ]),
        ]),
      });

      final branches = chain.stages[1];
      expect(chain.stages, hasLength(2));
      expect(branches.map((s) => s.name), ['vaporeon', 'espeon', 'leafeon']);
      expect((branches[0].trigger as UseItem).item, 'water-stone');
      expect((branches[1].trigger as Friendship).timeOfDay, 'day');
      expect((branches[2].trigger as UseItem).item, 'leaf-stone');
    });

    test('a single-stage chain has no evolutions', () {
      final chain = EvolutionChain.fromJson({
        'id': 66,
        'chain': _stageJson('tauros', 128, []),
      });

      expect(chain.isSingleStage, isTrue);
      expect(chain.stages, [
        [isA<EvolutionStage>()],
      ]);
    });

    test('survives a cache round trip', () {
      final chain = EvolutionChain.fromJson({
        'id': 67,
        'chain': _stageJson('eevee', 133, [], [
          _stageJson('jolteon', 135, [
            _detail('use-item', item: 'thunder-stone'),
          ]),
          _stageJson('umbreon', 197, [
            _detail('level-up', minHappiness: 160, timeOfDay: 'night'),
          ]),
        ]),
      });
      final cached = EvolutionChain.fromCacheJson(chain.toCacheJson());

      expect(cached.stages[1].map((s) => s.name), ['jolteon', 'umbreon']);
      expect((cached.stages[1][0].trigger as UseItem).item, 'thunder-stone');
      expect((cached.stages[1][1].trigger as Friendship).timeOfDay, 'night');
    });
  });

  group('defensive type matrix', () {
    const fire = TypeDamageRelations(
      doubleFrom: ['ground', 'rock', 'water'],
      halfFrom: ['bug', 'steel', 'fire', 'grass', 'ice', 'fairy'],
    );
    const flying = TypeDamageRelations(
      doubleFrom: ['electric', 'ice', 'rock'],
      halfFrom: ['grass', 'fighting', 'bug'],
      noFrom: ['ground'],
    );

    test('a single type maps directly to its damage relations', () {
      final defenses = TypeDefenses.calculate([fire]);

      expect(defenses.weaknesses.map((m) => m.multiplier), everyElement(2));
      expect(defenses.resistances, hasLength(6));
      expect(defenses.immunities, isEmpty);
    });

    test('dual types multiply: 4x, cancelled and 0x matchups', () {
      final defenses = TypeDefenses.calculate([fire, flying]);
      final weak = {for (final m in defenses.weaknesses) m.type: m.multiplier};
      final resist = {
        for (final m in defenses.resistances) m.type: m.multiplier,
      };

      expect(defenses.weaknesses.first, (type: 'rock', multiplier: 4.0));
      expect(weak, {'rock': 4.0, 'electric': 2.0, 'water': 2.0});
      // Ground is 2x on fire but 0x on flying: an immunity wins.
      expect(defenses.immunities, ['ground']);
      // Ice is 0.5x on fire and 2x on flying: neutral, so not listed.
      expect(weak.containsKey('ice'), isFalse);
      expect(resist.containsKey('ice'), isFalse);
      expect(resist['bug'], .25);
      expect(resist['grass'], .25);
      expect(resist['fire'], .5);
      expect(defenses.resistances.first.multiplier, .25);
    });

    test('type data keeps members sorted and relations cacheable', () {
      final data = PokemonTypeData.fromJson({
        'name': 'fire',
        'pokemon': [
          {
            'pokemon': _named(
              'charizard',
              'https://pokeapi.co/api/v2/pokemon/6/',
            ),
          },
          {
            'pokemon': _named(
              'charmander',
              'https://pokeapi.co/api/v2/pokemon/4/',
            ),
          },
        ],
        'damage_relations': {
          'double_damage_from': [
            _named('water', 'https://pokeapi.co/api/v2/type/11/'),
          ],
        },
      });
      final cached = PokemonTypeData.fromCacheJson(data.toCacheJson());

      expect(cached.members.map((e) => e.id), [4, 6]);
      expect(cached.damage.doubleFrom, ['water']);
    });
  });

  group('pokemon detail', () {
    Map<String, dynamic> json({Map<String, dynamic>? cries, bool art = true}) =>
        {
          'id': 10034,
          'name': 'charizard-mega-x',
          'height': 17,
          'weight': 1105,
          'base_experience': 285,
          'species': _named(
            'charizard',
            'https://pokeapi.co/api/v2/pokemon-species/6/',
          ),
          'cries': ?cries,
          'sprites': {
            'other': {
              'official-artwork': {
                'front_default': art ? pokemonArtworkUrl(10034) : null,
              },
              'showdown': {'front_default': null},
            },
          },
          'types': [
            {'type': _named('fire', '')},
            {'type': _named('dragon', '')},
          ],
          'stats': [
            {'stat': _named('hp', ''), 'base_stat': 78},
            {'stat': _named('attack', ''), 'base_stat': 130},
          ],
          'abilities': [
            {'ability': _named('tough-claws', ''), 'is_hidden': false},
            {'ability': _named('blaze', ''), 'is_hidden': true},
          ],
        };

    test('reads species id, sprites, cries and hidden abilities', () {
      final detail = PokemonDetail.fromJson(
        json(cries: {'latest': 'latest.ogg', 'legacy': 'legacy.ogg'}),
      );

      expect(detail.speciesId, 6);
      expect(detail.isBaseSpecies, isFalse);
      expect(detail.imageUrl, pokemonArtworkUrl(10034));
      expect(detail.animatedSpriteUrl, isNull);
      expect(detail.cryUrl, 'latest.ogg');
      expect(detail.heightM, 1.7);
      expect(detail.weightKg, 110.5);
      expect(detail.baseStatTotal, 208);
      expect(detail.abilities.where((a) => a.isHidden).single.name, 'blaze');
    });

    test('falls back to the legacy cry and to no artwork', () {
      final detail = PokemonDetail.fromJson(
        json(cries: {'latest': null, 'legacy': 'legacy.ogg'}, art: false),
      );

      expect(detail.cryUrl, 'legacy.ogg');
      expect(detail.imageUrl, isNull);
    });

    test('summaries keep the stats and survive a cache round trip', () {
      final detail = PokemonDetail.fromJson(json());
      final cached = PokemonDetail.fromCacheJson(detail.toCacheJson());
      final summary = PokemonSummary.fromCacheJson(
        cached.toSummary().toCacheJson(),
      );

      expect(cached.speciesId, 6);
      expect(summary.stats.map((s) => s.base), [78, 130]);
      expect(summary.imageUrl, pokemonArtworkUrl(10034));
    });

    test('saved records written without stats still load', () {
      final summary = PokemonSummary.fromCacheJson({
        'id': 25,
        'name': 'pikachu',
        'imageUrl': pokemonArtworkUrl(25),
        'types': ['electric'],
      });

      expect(summary.stats, isEmpty);
    });
  });

  test('parallel sources report cache only when every part was cached', () {
    expect(
      FetchSource.combine([const CacheHit(), const CacheHit()]),
      isA<CacheHit>(),
    );
    final mixed = FetchSource.combine([
      const CacheHit(),
      const NetworkFetch(Duration(milliseconds: 80)),
      const NetworkFetch(Duration(milliseconds: 120)),
    ]);
    expect((mixed as NetworkFetch).latency, const Duration(milliseconds: 120));
  });

  test('artwork URLs use the canonical HTTPS official-artwork path', () {
    expect(
      pokemonArtworkUrl(25),
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/25.png',
    );
  });
}
