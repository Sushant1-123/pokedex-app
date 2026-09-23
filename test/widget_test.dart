import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/core/constants.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/widgets/pagination_bar.dart';

import 'support/fakes.dart';

void main() {
  late FakeRepository repository;

  setUp(() => repository = FakeRepository(index: catalog(1025)));

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(repository),
        child: const PokedexApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size, columns) in const [
    ('mobile', Size(390, 844), 2),
    ('tablet', Size(820, 1180), 3),
    ('desktop', Size(1440, 1000), 5),
  ]) {
    testWidgets('renders the $columns-column directory on $name', (
      tester,
    ) async {
      await pumpApp(tester, size);

      expect(find.text('POKÉDEX TELEMETRY'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('1,025 specimens indexed'), findsOneWidget);
      expect(find.text('Pokemon 1'), findsOneWidget);
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        columns,
      );
    });
  }

  testWidgets('the pager changes page and scrolls back to the top', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 1000));

    final pager = find.descendant(
      of: find.byType(PaginationBar),
      matching: find.text('2'),
    );
    await tester.scrollUntilVisible(
      pager,
      500,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(pager);
    await tester.pumpAndSettle();

    expect(find.text('Pokemon 31'), findsOneWidget);
    expect(find.text('Pokemon 1'), findsNothing);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, 0);
    await tester.scrollUntilVisible(
      find.textContaining('Showing 31 – 60 of 1,025'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('LATENCY  42ms'), findsWidgets);
  });

  testWidgets(
    'Ctrl+K focuses search and the clear button empties it',
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    (tester) async {
      await pumpApp(tester, const Size(1440, 1000));
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      await tester.enterText(field, 'pokemon-25');
      await tester.pump(
        AppConstants.searchDebounce + const Duration(milliseconds: 50),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search Results'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('1,025 specimens indexed'), findsOneWidget);
    },
  );

  testWidgets('a type chip filters the directory', (tester) async {
    repository = FakeRepository(
      index: catalog(1025),
      typeMembers: {
        'fire': [4, 5, 6],
      },
    );
    await pumpApp(tester, const Size(1440, 1000));

    await tester.tap(find.text('FIRE').first);
    await tester.pumpAndSettle();

    expect(find.text('3 matches'), findsOneWidget);
    expect(find.text('Pokemon 4'), findsOneWidget);
  });
}
