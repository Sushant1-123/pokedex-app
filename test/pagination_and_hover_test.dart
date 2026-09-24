import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/theme.dart';
import 'package:pokedex_app/data/models/pokemon_summary.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/widgets/pagination_bar.dart';
import 'package:pokedex_app/presentation/widgets/pokemon_card.dart';

import 'support/fakes.dart';

void main() {
  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('mobile pagination bar', () {
    Future<List<int>> pumpBar(
      WidgetTester tester, {
      required int page,
      double width = 320,
    }) async {
      setSize(tester, Size(width, 640));
      final pages = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: PaginationBar(
                  page: page,
                  pageCount: 35,
                  onPage: pages.add,
                ),
              ),
            ),
          ),
        ),
      );
      return pages;
    }

    testWidgets('is used on phones instead of page numbers', (tester) async {
      await pumpBar(tester, page: 3);

      expect(find.byType(MobilePaginationBar), findsOneWidget);
      expect(find.text('Page 3 of 35'), findsOneWidget);
      expect(find.text('35'), findsNothing);
    });

    testWidgets('disables Prev on the first page', (tester) async {
      final pages = await pumpBar(tester, page: 1);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.tap(find.byTooltip('Next page'));
      expect(pages, [2]);
    });

    testWidgets('disables Next on the last page', (tester) async {
      final pages = await pumpBar(tester, page: 35);

      await tester.tap(find.byTooltip('Next page'));
      await tester.tap(find.byTooltip('Previous page'));
      expect(pages, [34]);
    });

    testWidgets('has tap targets of at least 44px', (tester) async {
      await pumpBar(tester, page: 2);

      for (final tooltip in ['Previous page', 'Next page']) {
        final size = tester.getSize(find.byTooltip(tooltip));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the page-jump sheet changes the page', (tester) async {
      final pages = await pumpBar(tester, page: 3);

      await tester.tap(find.text('Page 3 of 35'));
      await tester.pumpAndSettle();
      expect(find.text('JUMP TO PAGE'), findsOneWidget);
      final current = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Page 3',
        ),
      );
      expect(current.properties.selected, isTrue);

      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(pages, [12]);
      expect(find.text('JUMP TO PAGE'), findsNothing);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('does not overflow at ${width.toInt()}px', (tester) async {
        await pumpBar(tester, page: 35, width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('numbered pagination', () {
    test('collapses to the current page when space is tight', () {
      expect(pageWindow(18, 35, siblings: 0), [1, null, 18, null, 35]);
      expect(pageWindow(2, 35, siblings: 0), [1, 2, null, 35]);
    });

    testWidgets('fits a narrow tablet panel without overflow', (tester) async {
      setSize(tester, const Size(820, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 280,
              child: PaginationBar(page: 18, pageCount: 35, onPage: (_) {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('17'), findsNothing);
    });
  });

  group('directory on phones', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('pins the pager above the nav at ${width.toInt()}px', (
        tester,
      ) async {
        setSize(tester, Size(width, 700));
        await tester.pumpWidget(
          ProviderScope(
            overrides: appOverrides(FakeRepository(index: catalog(1025))),
            child: const PokedexApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final bar = find.byType(MobilePaginationBar);
        expect(bar, findsOneWidget);
        final nav = tester.getRect(find.text('MORE'));
        expect(tester.getRect(bar).bottom, lessThanOrEqualTo(nav.top));

        await tester.tap(find.text('Page 1 of 35'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        expect(find.text('Page 4 of 35'), findsOneWidget);
        expect(find.text('Pokemon 91'), findsOneWidget);
      });
    }
  });

  group('card hover', () {
    const pokemon = PokemonSummary(
      id: 1,
      name: 'bulbasaur',
      imageUrl: null,
      types: ['grass'],
    );

    test('the entry side comes from the pointer x-position', () {
      expect(entrySide(10, 200), -1);
      expect(entrySide(190, 200), 1);
    });

    test('the entrance slides in from the entry side and lands at rest', () {
      expect(CardArtPose.entrance(0, -1).dx, closeTo(-.4, 1e-9));
      expect(CardArtPose.entrance(0, 1).dx, closeTo(.4, 1e-9));
      expect(CardArtPose.entrance(0, 1).trail, 1);
      expect(CardArtPose.entrance(.7, 1).dy, lessThan(0));
      expect(CardArtPose.entrance(1, 1).squash, closeTo(0, 1e-9));
    });

    Future<void> pumpCards(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      setSize(tester, const Size(800, 600));
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(FakeRepository()),
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                disableAnimations: reduceMotion,
              ),
              child: Scaffold(
                body: Row(
                  children: [
                    for (final id in [1, 2])
                      SizedBox(
                        width: 240,
                        height: 380,
                        child: PokemonCard(
                          key: ValueKey(id),
                          pokemon: pokemon,
                          index: id,
                          onTap: () {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    CardArtPose poseOf(WidgetTester tester, int id) => tester
        .widget<CardArtwork>(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(CardArtwork),
          ),
        )
        .pose;

    Future<TestGesture> mouse(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: const Offset(790, 590));
      return gesture;
    }

    testWidgets('slides in from the entered side; other cards stay still', (
      tester,
    ) async {
      await pumpCards(tester);
      final gesture = await mouse(tester);
      final card = tester.getRect(find.byKey(const ValueKey(1)));

      await gesture.moveTo(card.centerRight - const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 60));
      expect(poseOf(tester, 1).dx, greaterThan(0));
      expect(poseOf(tester, 1).trail, greaterThan(0));
      expect(poseOf(tester, 2).atRest, isTrue);

      await gesture.moveTo(const Offset(790, 590));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.moveTo(card.centerLeft + const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 60));
      expect(poseOf(tester, 1).dx, lessThan(0));
    });

    testWidgets('returns to rest when the cursor leaves', (tester) async {
      await pumpCards(tester);
      final gesture = await mouse(tester);
      final card = tester.getRect(find.byKey(const ValueKey(1)));

      await gesture.moveTo(card.center);
      await tester.pump(const Duration(seconds: 1));
      expect(poseOf(tester, 1).atRest, isFalse);

      await gesture.moveTo(const Offset(790, 590));
      await tester.pumpAndSettle();
      expect(poseOf(tester, 1).atRest, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduce motion keeps the artwork still', (tester) async {
      await pumpCards(tester, reduceMotion: true);
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey(1))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(poseOf(tester, 1).atRest, isTrue);
    });

    testWidgets('touch only presses, without the hover animation', (
      tester,
    ) async {
      await pumpCards(tester);

      final touch = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey(1))),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(poseOf(tester, 1).atRest, isTrue);
      await touch.up();
      await tester.pumpAndSettle();
    });
  });

  test('no audio code or dependency remains', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('audio')));
    expect(
      File('pubspec.lock').readAsStringSync(),
      isNot(contains('audioplayers')),
    );
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in sources) {
      expect(
        file.readAsStringSync(),
        isNot(matches(RegExp('audioplayers|cryUrl|CryPlayer'))),
        reason: file.path,
      );
    }
  });
}
