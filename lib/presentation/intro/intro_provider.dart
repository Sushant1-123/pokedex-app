import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phases of the launch intro. It starts over on every app launch / web page
/// load (a new ProviderScope) and never replays on in-app navigation.
enum IntroPhase {
  /// Trainer, throw, flight, landing and wobble.
  playing,

  /// The ball splits and the app is revealed behind the halves.
  revealing,

  /// Intro removed; only the app is shown.
  done,
}

class IntroNotifier extends Notifier<IntroPhase> {
  @override
  IntroPhase build() => IntroPhase.playing;

  /// Jumps straight to the reveal (SKIP button, tap anywhere, or the end of
  /// the throw sequence).
  void reveal() {
    if (state == IntroPhase.playing) state = IntroPhase.revealing;
  }

  void finish() => state = IntroPhase.done;
}

final introProvider = NotifierProvider<IntroNotifier, IntroPhase>(
  IntroNotifier.new,
);
