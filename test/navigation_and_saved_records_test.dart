import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/result.dart';
import 'package:pokedex_app/data/datasources/pokeapi_client.dart';
import 'package:pokedex_app/data/datasources/pokemon_cache.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/repositories/pokemon_repository.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/providers/app_navigation_provider.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/saved_records_provider.dart';
import 'package:pokedex_app/presentation/providers/telemetry_provider.dart';
import 'package:pokedex_app/presentation/screens/saved_records_screen.dart';

void main() {
  test('navigation notifier tracks the active field destination', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(appNavigationProvider.notifier)
        .select(AppDestination.telemetry);
    expect(container.read(appNavigationProvider), AppDestination.telemetry);

    container.read(appNavigationProvider.notifier).select(AppDestination.saved);
    expect(container.read(appNavigationProvider), AppDestination.saved);
  });

  test('telemetry aggregates detail measurements and base stats', () {
    const summaries = [
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
    const details = [
      PokemonDetail(
        id: 1,
        name: 'bulbasaur',
        imageUrl: 'bulbasaur.png',
        types: ['grass', 'poison'],
        stats: [PokemonStat(name: 'hp', base: 45)],
        abilities: [],
        heightM: 0.7,
        weightKg: 6.9,
      ),
      PokemonDetail(
        id: 4,
        name: 'charmander',
        imageUrl: 'charmander.png',
        types: ['fire'],
        stats: [PokemonStat(name: 'hp', base: 39)],
        abilities: [],
        heightM: 0.6,
        weightKg: 8.5,
      ),
    ];

    final telemetry = TelemetryData.fromDetails(summaries, details);

    expect(telemetry.totalSpecimens, 2);
    expect(telemetry.typeCounts, {'grass': 1, 'poison': 1, 'fire': 1});
    expect(telemetry.averageHeightM, closeTo(0.65, 0.001));
    expect(telemetry.averageWeightKg, closeTo(7.7, 0.001));
    expect(telemetry.averageBaseStats['hp'], closeTo(42, 0.001));
  });

  test(
    'saved records can be added, removed, and loaded by a new container',
    () async {
      final cache = _FakePokemonCache();
      const pokemon = PokemonSummary(
        id: 25,
        name: 'pikachu',
        imageUrl: 'pikachu.png',
        types: ['electric'],
      );

      final first = ProviderContainer(
        overrides: [pokemonCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(first.dispose);
      first.read(savedRecordsProvider.notifier).load();
      await first.read(savedRecordsProvider.notifier).toggle(pokemon);

      expect(_saved(first).map((record) => record.id), [pokemon.id]);

      final second = ProviderContainer(
        overrides: [pokemonCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(second.dispose);
      second.read(savedRecordsProvider.notifier).load();
      expect(_saved(second).map((record) => record.id), [pokemon.id]);

      await second.read(savedRecordsProvider.notifier).toggle(pokemon);
      expect(_saved(second), isEmpty);
    },
  );

  testWidgets('desktop navigation opens telemetry and saved records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_AppHarness(cache: _FakePokemonCache()));
    await tester.pumpAndSettle();

    expect(find.text('Specimen index'), findsOneWidget);
    await tester.tap(find.text('Telemetry'));
    await tester.pumpAndSettle();
    expect(find.text('TELEMETRY'), findsOneWidget);
    expect(find.text('Specimen index'), findsOneWidget);

    final savedLabel = find.text('Saved records');
    expect(savedLabel, findsOneWidget);
    await tester.tapAt(tester.getCenter(savedLabel));
    await tester.pumpAndSettle();
    expect(find.text('NO SAVED RECORDS'), findsOneWidget);
  });

  testWidgets('mobile bottom navigation opens telemetry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_AppHarness(cache: _FakePokemonCache()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('TELEMETRY'), findsOneWidget);
  });

  testWidgets('saved records starts with a designed empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonCacheProvider.overrideWithValue(_FakePokemonCache()),
        ],
        child: const MaterialApp(home: SavedRecordsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('NO SAVED RECORDS'), findsOneWidget);
  });
}

List<PokemonSummary> _saved(ProviderContainer container) {
  final result = container.read(savedRecordsProvider);
  return switch (result) {
    Success<List<PokemonSummary>>(data: final records) => records,
    _ => const <PokemonSummary>[],
  };
}

class _AppHarness extends StatelessWidget {
  final PokemonCache cache;
  const _AppHarness({required this.cache});

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      pokemonCacheProvider.overrideWithValue(cache),
      pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
    ],
    child: const PokedexApp(),
  );
}

class _FakeRepository extends PokemonRepository {
  _FakeRepository()
    : super(client: PokeApiClient(), cache: _FakePokemonCache());

  @override
  Future<(List<PokemonSummary> items, bool fromCache)> getPokemonPage({
    required int offset,
    required int limit,
  }) async {
    return (
      [
        const PokemonSummary(
          id: 1,
          name: 'bulbasaur',
          imageUrl: 'bulbasaur.png',
          types: ['grass', 'poison'],
        ),
      ],
      false,
    );
  }

  @override
  Future<(PokemonDetail detail, bool fromCache)> getPokemonDetail(
    String nameOrId,
  ) async {
    return (
      const PokemonDetail(
        id: 1,
        name: 'bulbasaur',
        imageUrl: 'bulbasaur.png',
        types: ['grass', 'poison'],
        stats: [PokemonStat(name: 'hp', base: 45)],
        abilities: [],
        heightM: 0.7,
        weightKg: 6.9,
      ),
      true,
    );
  }
}

class _FakePokemonCache extends PokemonCache {
  final Map<String, Map<String, dynamic>> _records = {};

  @override
  List<Map<String, dynamic>> readSavedRecords() => _records.values.toList();

  @override
  Future<void> writeSavedRecord(Map<String, dynamic> data) async {
    _records[data['id'].toString()] = data;
  }

  @override
  Future<void> deleteSavedRecord(int id) async {
    _records.remove(id.toString());
  }
}
