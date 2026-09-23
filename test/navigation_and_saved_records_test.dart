import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/result.dart';
import 'package:pokedex_app/core/theme.dart';
import 'package:pokedex_app/data/models/pokemon_detail.dart';
import 'package:pokedex_app/data/models/pokemon_stat.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/providers/app_navigation_provider.dart';
import 'package:pokedex_app/presentation/providers/core_providers.dart';
import 'package:pokedex_app/presentation/providers/saved_records_provider.dart';
import 'package:pokedex_app/presentation/providers/telemetry_provider.dart';
import 'package:pokedex_app/presentation/screens/saved_records_screen.dart';

import 'support/fakes.dart';

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
    PokemonDetail detail(int id, List<String> types, int hp, double h) =>
        PokemonDetail(
          id: id,
          name: 'pokemon-$id',
          speciesId: id,
          imageUrl: null,
          types: types,
          stats: [PokemonStat(name: 'hp', base: hp)],
          abilities: const [],
          heightM: h,
          weightKg: h * 10,
        );

    final telemetry = TelemetryData.fromDetails([
      detail(1, ['grass', 'poison'], 45, .7),
      detail(4, ['fire'], 39, .6),
    ]);

    expect(telemetry.totalSpecimens, 2);
    expect(telemetry.typeCounts, {'grass': 1, 'poison': 1, 'fire': 1});
    expect(telemetry.averageHeightM, closeTo(0.65, 0.001));
    expect(telemetry.averageWeightKg, closeTo(6.5, 0.001));
    expect(telemetry.averageBaseStats['hp'], closeTo(42, 0.001));
  });

  test('telemetry samples the first page of base species', () async {
    final repository = FakeRepository(index: catalog(100));
    final container = ProviderContainer(
      overrides: [pokemonRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(telemetryProvider.notifier).load();

    final data = (container.read(telemetryProvider) as Success).data;
    expect(
      (data as TelemetryData).totalSpecimens,
      TelemetryNotifier.sampleSize,
    );
    expect(repository.detailRequests.toSet(), {
      for (var id = 1; id <= TelemetryNotifier.sampleSize; id++) id,
    });
  });

  test(
    'saved records can be added and removed through the repository',
    () async {
      final repository = FakeRepository();
      const pokemon = PokemonSummary(
        id: 25,
        name: 'pikachu',
        imageUrl: null,
        types: ['electric'],
      );
      final container = ProviderContainer(
        overrides: [pokemonRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(savedRecordsProvider.notifier)..load();

      await notifier.toggle(pokemon);
      expect(_saved(container).map((record) => record.id), [25]);
      expect(repository.saved.keys, [25]);

      await notifier.toggle(pokemon);
      expect(_saved(container), isEmpty);
    },
  );

  testWidgets('desktop navigation opens telemetry and saved records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(FakeRepository(index: catalog(40))));
    await tester.pumpAndSettle();

    expect(find.text('Specimen Stream'), findsOneWidget);
    await tester.tap(find.text('Diagnostic Matrix'));
    await tester.pumpAndSettle();
    expect(find.text('Specimen Field Readings'), findsOneWidget);
    expect(find.textContaining('SAMPLE: THE FIRST 30'), findsOneWidget);

    await tester.tap(find.text('Saved Records'));
    await tester.pumpAndSettle();
    expect(find.text('NO SAVED RECORDS'), findsOneWidget);
  });

  testWidgets('mobile More sheet opens the diagnostic matrix', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(FakeRepository(index: catalog(40))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MORE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnostic Matrix'));
    await tester.pumpAndSettle();
    expect(find.text('Specimen Field Readings'), findsOneWidget);
  });

  testWidgets('saved records starts with a designed empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(FakeRepository()),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SavedRecordsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NO SAVED RECORDS'), findsOneWidget);
  });
}

List<PokemonSummary> _saved(ProviderContainer container) {
  return switch (container.read(savedRecordsProvider)) {
    Success<List<PokemonSummary>>(data: final records) => records,
    _ => const <PokemonSummary>[],
  };
}

Widget _app(FakeRepository repository) => ProviderScope(
  overrides: appOverrides(repository),
  child: const PokedexApp(),
);
