import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/presentation/intro/intro_overlay.dart';
import 'package:pokedex_app/presentation/intro/intro_provider.dart';
import 'package:pokedex_app/presentation/intro/intro_scene.dart';

import 'support/fakes.dart';

void main() {
  late FakeRepository repository;

  setUp(() => repository = FakeRepository(index: catalog(40)));

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(repository, skipIntro: false),
        child: const PokedexApp(),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(PokedexApp)));
  }

  IntroPhase phase(ProviderContainer container) =>
      container.read(introProvider);

  /// Animation controllers start timing on their first tick, so pump one
  /// frame before advancing the clock.
  Future<void> advance(WidgetTester tester, Duration duration) async {
    await tester.pump();
    await tester.pump(duration + const Duration(milliseconds: 50));
    await tester.pump();
  }

  testWidgets('plays on launch and preloads the directory underneath', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    expect(phase(container), IntroPhase.playing);
    expect(find.text('SKIP'), findsOneWidget);
    // The index and first page load while the intro is still playing.
    expect(repository.indexRequests, 1);
    expect(repository.detailRequests, isNotEmpty);

    await advance(tester, IntroGate.playDuration);
    expect(phase(container), IntroPhase.revealing);
    await advance(tester, IntroGate.revealDuration);
    expect(phase(container), IntroPhase.done);
    expect(find.text('SKIP'), findsNothing);
  });

  testWidgets('SKIP jumps to the reveal and shows the directory', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('SKIP'));
    await tester.pump();
    expect(phase(container), IntroPhase.revealing);

    await advance(tester, IntroGate.revealDuration);
    expect(phase(container), IntroPhase.done);
    expect(find.text('Specimen Repository'), findsOneWidget);
    expect(find.text('Pokemon 1'), findsWidgets);
  });

  testWidgets('tapping anywhere also skips', (tester) async {
    final container = await pumpApp(tester);

    await tester.tapAt(const Offset(640, 450));
    await tester.pump();
    expect(phase(container), IntroPhase.revealing);
  });

  testWidgets('reduce motion replaces it with a short fade', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final container = await pumpApp(tester);
    await tester.pump();
    expect(phase(container), IntroPhase.revealing);
    expect(
      IntroGate.reducedMotionDuration,
      lessThan(const Duration(milliseconds: 400)),
    );

    await advance(tester, IntroGate.reducedMotionDuration);
    expect(phase(container), IntroPhase.done);
  });

  testWidgets('does not replay when navigating inside the app', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.text('SKIP'));
    await advance(tester, IntroGate.revealDuration);

    await tester.tap(find.text('Diagnostic Matrix'));
    await tester.pumpAndSettle();
    expect(find.text('Specimen Field Readings'), findsOneWidget);
    expect(phase(container), IntroPhase.done);
    expect(find.text('SKIP'), findsNothing);
  });

  testWidgets('plays in full at 1440x900 when reduce motion is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(repository, skipIntro: false),
        child: const PokedexApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PokedexApp)),
    );
    await tester.pump();

    // Not skipped or shortened: still throwing just before the full length.
    await tester.pump(
      IntroGate.playDuration - const Duration(milliseconds: 100),
    );
    expect(phase(container), IntroPhase.playing);
    await advance(tester, const Duration(milliseconds: 100));
    expect(phase(container), IntroPhase.revealing);
    await advance(tester, IntroGate.revealDuration);
    expect(phase(container), IntroPhase.done);
  });

  testWidgets('the trainer artwork asset loads', (tester) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load(TrainerArt.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width / frame.image.height, TrainerArt.aspectRatio);
    });
  });

  group('intro layout', () {
    const sizes = [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 720),
      Size(1366, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ];

    test('the ball leaves exactly from the measured hand position', () {
      for (final size in sizes) {
        final layout = IntroLayout(size);
        final rect = layout.trainerRect;
        // Standing still (after the dash-in, before the wind-up) the hand is
        // exactly at the constant's position in the artwork.
        final standing = layout.handAt(.15);
        expect(
          standing.dx,
          closeTo(rect.left + TrainerArt.hand.dx * rect.width, .5),
        );
        expect(
          standing.dy,
          closeTo(rect.top + TrainerArt.hand.dy * rect.height, .5),
        );
        // At release the ball is where the posed hand is.
        final release = layout.handAt(IntroTimeline.release);
        final justBefore = layout.handAt(IntroTimeline.release - .0005);
        expect((release - justBefore).distance, lessThan(4));
      }
    });

    test('trainer and ball fit and read at every screen size', () {
      for (final size in sizes) {
        final layout = IntroLayout(size);
        final rect = layout.trainerRect;
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$size');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$size');
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$size');
        expect(rect.width / rect.height, closeTo(TrainerArt.aspectRatio, 1e-9));
        expect(rect.height, greaterThan(size.height * .3), reason: '$size');
        expect(
          rect.right,
          lessThan(layout.landing.dx - layout.ballRadius),
          reason: '$size',
        );
      }
    });
  });
}
