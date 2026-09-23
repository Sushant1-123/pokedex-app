import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/core/design_tokens.dart';
import 'package:pokedex_app/core/result.dart';
import 'package:pokedex_app/data/models/pokemon_index_entry.dart';
import 'package:pokedex_app/data/models/pokemon_type_data.dart';
import 'package:pokedex_app/data/models/type_chart.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/name_index_provider.dart';
import 'package:pokedex_app/presentation/providers/section_providers.dart';
import 'package:pokedex_app/presentation/widgets/detail/specimen_choreography.dart';

import 'support/fakes.dart';

void main() {
  group('species colour glow', () {
    test('maps every PokeAPI colour to its glow token', () {
      for (final colour in [
        'red',
        'blue',
        'yellow',
        'green',
        'black',
        'brown',
        'purple',
        'gray',
        'white',
        'pink',
      ]) {
        expect(
          pokemonGlowColor(colour, const ['normal']),
          AppColors.speciesGlow[colour],
          reason: colour,
        );
      }
    });

    test('black and gray still read on the dark surface', () {
      for (final colour in ['black', 'gray']) {
        final glow = AppColors.speciesGlow[colour]!;
        expect(
          glow.computeLuminance(),
          greaterThan(AppColors.surface.computeLuminance() + .2),
          reason: colour,
        );
      }
    });

    test('falls back to the primary type colour, then cyan', () {
      expect(pokemonGlowColor(null, const ['fire']), colorForType('fire'));
      expect(pokemonGlowColor('teal', const ['water']), colorForType('water'));
      expect(pokemonGlowColor(null, const []), AppColors.cyan);
    });
  });

  test('stat bar colours follow the token thresholds', () {
    expect(AppStatScale.colorFor(AppStatScale.mid - 1), AppColors.textMuted);
    expect(AppStatScale.colorFor(AppStatScale.mid), AppColors.cyan);
    expect(AppStatScale.colorFor(AppStatScale.high - 1), AppColors.cyan);
    expect(AppStatScale.colorFor(AppStatScale.high), AppColors.crimson);
    expect(AppStatScale.colorFor(255), AppColors.crimson);
  });

  group('specimen choreography', () {
    test('taps alternate jump and kick', () {
      final moves = TapMoves();
      expect(
        [for (var i = 0; i < 4; i++) moves.take()],
        [
          SpecimenMove.jump,
          SpecimenMove.kick,
          SpecimenMove.jump,
          SpecimenMove.kick,
        ],
      );
    });

    test('reduce motion goes straight to the rest pose', () {
      for (final t in [0.0, .2, .5, .8]) {
        expect(
          SpecimenChoreography.entrance(t, reducedMotion: true),
          SpecimenChoreography.rest,
        );
      }
    });

    test('the entrance runs in, jumps, kicks and ends at rest', () {
      final start = SpecimenChoreography.entrance(0);
      expect(start.dx, lessThan(-1));
      expect(start.trail, greaterThan(0));
      final airborne = SpecimenChoreography.entrance(.5);
      expect(airborne.dy, lessThan(-.2));
      final kick = SpecimenChoreography.entrance(.85);
      expect(kick.flash, greaterThan(.5));
      expect(kick.angle, greaterThan(0));
      expect(SpecimenChoreography.entrance(1), SpecimenChoreography.rest);
      expect(
        SpecimenChoreography.entranceDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 1600)),
      );
    });

    test('moves start and end at rest, with a ring on landing', () {
      for (final move in SpecimenMove.values) {
        final end = SpecimenChoreography.move(move, 1);
        expect(end.dx, closeTo(0, 1e-9));
        expect(end.dy, closeTo(0, 1e-9));
        expect(end.angle, closeTo(0, 1e-9));
      }
      expect(SpecimenChoreography.jumpAt(.9).ring, greaterThan(0));
      expect(SpecimenChoreography.jumpAt(.5).dy, lessThan(-.3));
    });
  });

  test('the type chart builder fills the full 18x18 matrix', () {
    final chart = TypeChart.build(chartTypes, {
      for (final type in chartTypes) type: const TypeDamageRelations(),
      'fire': const TypeDamageRelations(
        doubleFrom: ['water', 'rock', 'ground'],
        halfFrom: ['grass', 'fire'],
      ),
      'ghost': const TypeDamageRelations(noFrom: ['normal', 'fighting']),
    });

    expect(chart.types, hasLength(18));
    var cells = 0;
    for (final a in chart.types) {
      for (final d in chart.types) {
        expect([0.0, .5, 1.0, 2.0], contains(chart.multiplier(a, d)));
        cells++;
      }
    }
    expect(cells, 18 * 18);
    expect(chart.multiplier('water', 'fire'), 2);
    expect(chart.multiplier('grass', 'fire'), .5);
    expect(chart.multiplier('normal', 'ghost'), 0);
    expect(chart.multiplier('fire', 'water'), 1);
    expect(chart.weakTo('fire'), ['water', 'ground', 'rock']);
    expect(chart.immuneTo('ghost'), ['normal', 'fighting']);
    expect(chart.strongAgainst('water'), ['fire']);
  });

  group('compare lab', () {
    test('holds at most three Pokemon and no duplicates', () async {
      final container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakeRepository(index: catalog(10)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final lab = container.read(compareProvider.notifier);

      expect(lab.add(1), isTrue);
      expect(lab.add(1), isFalse);
      expect(lab.add(2), isTrue);
      expect(lab.add(3), isTrue);
      expect(lab.add(4), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final picks = container.read(compareProvider);
      expect(picks.map((p) => p.id), [1, 2, 3]);
      expect(picks, everyElement(isA<PickReady>()));

      lab.remove(2);
      expect(lab.add(4), isTrue);
      expect(container.read(compareProvider).map((p) => p.id), [1, 3, 4]);
    });
  });

  group('evolution engine', () {
    test('a searched Pokemon resolves to its chain', () async {
      final container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakeRepository(
              index: catalog(
                10,
                extra: const [PokemonIndexEntry(id: 7, name: 'squirtle')],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final engine = container.read(evolutionEngineProvider.notifier);
      expect(container.read(evolutionEngineProvider), isNull);

      container.read(nameIndexProvider);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final hits = container
          .read(nameIndexProvider.notifier)
          .suggestions('squirt');
      await engine.open(hits.single);

      final lookup = container.read(evolutionEngineProvider);
      expect(lookup, isA<Success<EvolutionLookup>>());
      final data = (lookup as Success<EvolutionLookup>).data;
      expect(data.entry.name, 'squirtle');
      expect(data.chain.isSingleStage, isTrue);
      expect(data.chain.root.speciesId, 7);
    });

    test('random chain picks a base species', () async {
      final container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakeRepository(index: catalog(5)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(evolutionEngineProvider.notifier).openRandom();

      final lookup = container.read(evolutionEngineProvider);
      expect(
        (lookup as Success<EvolutionLookup>).data.entry.id,
        inInclusiveRange(1, 5),
      );
    });
  });
}
