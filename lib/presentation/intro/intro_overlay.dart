import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_tokens.dart';
import '../providers/pokemon_list_provider.dart';
import 'intro_painters.dart';
import 'intro_provider.dart';
import 'intro_scene.dart';

/// Wraps the app (above the Navigator, via MaterialApp.builder) and plays the
/// launch intro over it. The app is built underneath from the start, so the
/// current route (including deep links like /telemetry) is revealed behind
/// the splitting Poke Ball rather than hard-cut in.
class IntroGate extends ConsumerStatefulWidget {
  final Widget child;
  const IntroGate({super.key, required this.child});

  static const playDuration = Duration(milliseconds: 2800);
  static const revealDuration = Duration(milliseconds: 600);
  static const reducedMotionDuration = Duration(milliseconds: 350);

  @override
  ConsumerState<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends ConsumerState<IntroGate>
    with TickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: IntroGate.playDuration,
  );
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: IntroGate.revealDuration,
  );
  bool _started = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    // Start loading the name index and first page while the intro plays.
    ref.read(pokemonListProvider);
    _play.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifier.reveal();
    });
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifier.finish();
    });
  }

  IntroNotifier get _notifier => ref.read(introProvider.notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || ref.read(introProvider) != IntroPhase.playing) return;
    _started = true;
    // Decode the trainer now (the web boot screen already preloads the
    // file), so it is ready before he slides in.
    precacheImage(const AssetImage(TrainerArt.asset), context);
    // True only when the OS asks for reduced motion: "Animation effects"
    // off on Windows, "Reduce motion" on macOS/iOS, "Remove animations" on
    // Android, or prefers-reduced-motion in the browser.
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _reveal.duration = IntroGate.reducedMotionDuration;
      // Provider state can't change while the tree is building.
      scheduleMicrotask(_notifier.reveal);
    } else {
      _play.forward();
    }
  }

  @override
  void dispose() {
    _play.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(introProvider, (_, phase) {
      if (phase == IntroPhase.revealing) {
        _play.stop();
        _reveal.forward();
      }
    });
    final phase = ref.watch(introProvider);
    // The child keeps its position in the Stack in every phase, so the
    // Navigator underneath is never rebuilt when the overlay goes away.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (phase != IntroPhase.done)
          Positioned.fill(
            child: _IntroScene(
              play: _play,
              reveal: _reveal,
              reducedMotion: _reducedMotion,
              onSkip: phase == IntroPhase.playing ? _notifier.reveal : null,
            ),
          ),
      ],
    );
  }
}

class _IntroScene extends StatelessWidget {
  final Animation<double> play;
  final Animation<double> reveal;
  final bool reducedMotion;
  final VoidCallback? onSkip;

  const _IntroScene({
    required this.play,
    required this.reveal,
    required this.reducedMotion,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final scene = AnimatedBuilder(
      animation: Listenable.merge([play, reveal]),
      builder: (context, _) {
        final chromeOpacity = (1 - reveal.value * 3).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (reducedMotion)
              CustomPaint(painter: _CalmIntroPainter(fade: reveal.value))
            else ...[
              CustomPaint(
                painter: IntroBackdropPainter(
                  play: play.value,
                  reveal: reveal.value,
                ),
              ),
              if (reveal.value == 0) _Trainer(play: play.value),
              CustomPaint(
                painter: IntroForegroundPainter(
                  play: play.value,
                  reveal: reveal.value,
                ),
              ),
            ],
            Opacity(
              opacity: chromeOpacity,
              child: _SceneChrome(onSkip: onSkip),
            ),
          ],
        );
      },
    );
    // The overlay sits above the Navigator, so it provides its own
    // Material for text and button styling.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Intro animation',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSkip,
          child: scene,
        ),
      ),
    );
  }
}

/// The trainer artwork, posed by [IntroLayout.poseAt] around his feet.
class _Trainer extends StatelessWidget {
  final double play;
  const _Trainer({required this.play});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = IntroLayout(constraints.biggest);
      final pose = layout.poseAt(play);
      if (pose.opacity <= 0) return const SizedBox.shrink();
      final rect = layout.trainerRect;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: layout.trainerTransform(pose),
              child: Opacity(
                opacity: pose.opacity,
                child: Image.asset(
                  TrainerArt.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Wordmark, status caption and the SKIP button.
class _SceneChrome extends StatelessWidget {
  final VoidCallback? onSkip;
  const _SceneChrome({required this.onSkip});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CustomPaint(painter: PokeBallPainter()),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('POKÉDEX', style: AppTypography.titleSmall),
                    Text(
                      'FIELD RESEARCH UNIT',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
              if (onSkip != null)
                OutlinedButton.icon(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: AppColors.container.withValues(alpha: .7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('SKIP', style: AppTypography.label),
                ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              'INITIALISING FIELD DATABASE',
              style: AppTypography.caption.copyWith(letterSpacing: 2.4),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Reduced-motion replacement: the closed ball on the dark surface, faded
/// out over a few hundred milliseconds.
class _CalmIntroPainter extends CustomPainter {
  final double fade;
  const _CalmIntroPainter({required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = 1 - fade;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface.withValues(alpha: opacity),
    );
    final r = (size.shortestSide * .065).clamp(16.0, 52.0);
    canvas
      ..saveLayer(
        Offset.zero & size,
        Paint()..color = AppColors.surfaceSunken.withValues(alpha: opacity),
      )
      ..translate(size.width / 2 - r, size.height / 2 - r);
    const PokeBallPainter().paint(canvas, Size.square(r * 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CalmIntroPainter old) => old.fade != fade;
}
