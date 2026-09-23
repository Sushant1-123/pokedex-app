import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/intro/intro_overlay.dart';
import 'package:pokedex_app/presentation/intro/intro_provider.dart';
import 'package:pokedex_app/presentation/providers/app_navigation_provider.dart';
import 'package:pokedex_app/presentation/screens/pokemon_list_screen.dart';
import 'package:pokedex_app/presentation/screens/saved_records_screen.dart';
import 'package:pokedex_app/presentation/screens/sections/ability_codex_screen.dart';
import 'package:pokedex_app/presentation/screens/sections/compare_lab_screen.dart';
import 'package:pokedex_app/presentation/screens/sections/evolution_engine_screen.dart';
import 'package:pokedex_app/presentation/screens/sections/habitat_radar_screen.dart';
import 'package:pokedex_app/presentation/screens/sections/type_spectra_screen.dart';
import 'package:pokedex_app/presentation/screens/telemetry_screen.dart';

import 'support/fakes.dart';

const _screens = {
  AppDestination.specimenIndex: PokemonListScreen,
  AppDestination.telemetry: TelemetryScreen,
  AppDestination.evolution: EvolutionEngineScreen,
  AppDestination.types: TypeSpectraScreen,
  AppDestination.habitats: HabitatRadarScreen,
  AppDestination.compare: CompareLabScreen,
  AppDestination.abilities: AbilityCodexScreen,
  AppDestination.saved: SavedRecordsScreen,
};

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    String route = '/',
    Size size = const Size(1440, 1000),
    bool skipIntro = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.defaultRouteNameTestValue = route;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          FakeRepository(index: catalog(40)),
          skipIntro: skipIntro,
        ),
        child: const PokedexApp(),
      ),
    );
  }

  test('there are eight destinations with unique routes', () {
    expect(AppDestination.values, hasLength(8));
    expect(AppDestination.values.map((d) => d.path).toSet(), hasLength(8));
    expect(AppDestination.values.map((d) => d.label), [
      'Specimen Stream',
      'Diagnostic Matrix',
      'Evolution Engine',
      'Type Spectra',
      'Habitat Radar',
      'Compare Lab',
      'Ability Codex',
      'Saved Records',
    ]);
    expect(AppDestination.fromPath('/telemetry'), AppDestination.telemetry);
    expect(AppDestination.fromPath('/nope'), AppDestination.specimenIndex);
  });

  for (final MapEntry(key: destination, value: screen) in _screens.entries) {
    testWidgets('deep link ${destination.path} opens ${destination.label}', (
      tester,
    ) async {
      await pumpApp(tester, route: destination.path);
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
    });
  }

  testWidgets('a deep link plays the intro, then reveals that screen', (
    tester,
  ) async {
    await pumpApp(tester, route: '/types', skipIntro: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PokedexApp)),
    );
    await tester.pump();
    expect(container.read(introProvider), IntroPhase.playing);

    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(
      IntroGate.revealDuration + const Duration(milliseconds: 50),
    );
    await tester.pump();

    expect(container.read(introProvider), IntroPhase.done);
    expect(find.byType(TypeSpectraScreen), findsOneWidget);
  });

  testWidgets('mobile: three tabs plus a More sheet with the rest', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844));
    await tester.pumpAndSettle();

    for (final label in [
      'SPECIMEN STREAM',
      'EVOLUTION ENGINE',
      'TYPE SPECTRA',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('MORE'));
    await tester.pumpAndSettle();
    for (final label in [
      'Diagnostic Matrix',
      'Habitat Radar',
      'Compare Lab',
      'Ability Codex',
      'Saved Records',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Habitat Radar'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitatRadarScreen), findsOneWidget);
  });
}
