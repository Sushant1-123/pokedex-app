import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/theme.dart';
import 'package:pokedex_app/presentation/providers/pokemon_detail_provider.dart';
import 'package:pokedex_app/presentation/screens/pokemon_detail_screen.dart';
import 'package:pokedex_app/presentation/widgets/detail/specimen_viewport.dart';
import 'package:pokedex_app/presentation/widgets/pokemon_image.dart';

import 'support/fakes.dart';

const _sprite = 'https://raw.githubusercontent.com/showdown/2.gif';

void main() {
  late FakeRepository repository;
  late FakeCryPlayer cries;

  setUp(() {
    repository = FakeRepository(
      index: catalog(151),
      animatedSprites: const {2: _sprite},
    );
    cries = FakeCryPlayer();
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    int id, {
    Size size = const Size(1280, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(repository, cryPlayer: cries),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: PokemonDetailScreen(pokemonId: id),
        ),
      ),
    );
    // Record, sections, then entrance and type-badge stagger.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(PokemonDetailScreen)),
    );
  }

  Finder link(String text) => find.textContaining(text, findRichText: true);
  Finder viewportImage(String? url) => find.descendant(
    of: find.byType(SpecimenViewport),
    matching: find.byWidgetPredicate((w) => w is PokemonImage && w.url == url),
  );

  group('prev/next navigation', () {
    testWidgets('#1 hides previous and links to #2', (tester) async {
      await open(tester, 1);

      expect(find.byTooltip('Previous specimen'), findsNothing);
      expect(find.byTooltip('Next specimen'), findsOneWidget);
      expect(link('#0002 Pokemon 2'), findsOneWidget);
    });

    testWidgets('the last species hides next', (tester) async {
      await open(tester, 151);

      expect(find.byTooltip('Previous specimen'), findsOneWidget);
      expect(find.byTooltip('Next specimen'), findsNothing);
    });

    testWidgets('next opens the following specimen', (tester) async {
      await open(tester, 1);

      await tester.tap(find.byTooltip('Next specimen'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(link('DIRECTORY / #0002'), findsOneWidget);
      expect(find.byTooltip('Previous specimen'), findsOneWidget);
    });
  });

  group('animated sprite toggle', () {
    testWidgets('is disabled with a tooltip when there is no sprite', (
      tester,
    ) async {
      final container = await open(tester, 1);

      expect(find.byTooltip('No animated sprite'), findsOneWidget);
      await tester.tap(find.text('ANIMATED'));
      await tester.pump();

      expect(container.read(animatedSpriteProvider), isFalse);
      expect(viewportImage(_sprite), findsNothing);
    });

    testWidgets('switches to the Showdown sprite when one exists', (
      tester,
    ) async {
      final container = await open(tester, 2);

      await tester.tap(find.byTooltip('Show animated sprite'));
      await tester.pump();

      expect(container.read(animatedSpriteProvider), isTrue);
      expect(viewportImage(_sprite), findsOneWidget);
    });

    testWidgets('falls back to the artwork on a Pokemon without a sprite', (
      tester,
    ) async {
      final container = await open(tester, 1);
      container.read(animatedSpriteProvider.notifier).toggle();
      await tester.pump();

      expect(viewportImage(repository.detailFor(1).imageUrl), findsOneWidget);
    });
  });

  testWidgets('tapping the Pokemon plays its cry', (tester) async {
    await open(tester, 3);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Play cry',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(cries.played, ['https://example.test/cries/3.ogg']);
  });

  group('responsive layout', () {
    for (final (name, size) in const [
      ('mobile', Size(390, 844)),
      ('tablet', Size(820, 1180)),
      ('desktop', Size(1440, 1000)),
    ]) {
      testWidgets('renders every section on $name without overflow', (
        tester,
      ) async {
        await open(tester, 2, size: size);

        for (final title in [
          'BASE STAT CALIBRATION',
          'INHERENT CAPABILITIES',
          'DEFENSIVE SPECTRAL MATRIX',
          'PHYSICAL METRIC TELEMETRY',
          'FIELD NOTES',
        ]) {
          await tester.scrollUntilVisible(
            find.text(title),
            300,
            scrollable: find
                .ancestor(
                  of: find.text('Back to Directory'),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('HIDDEN'), findsOneWidget);
        expect(find.text('87.5%'), findsOneWidget);
      });
    }
  });
}
