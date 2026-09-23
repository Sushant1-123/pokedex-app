import 'package:audioplayers/audioplayers.dart';

/// Plays a Pokemon cry from the `cries` URL PokeAPI returns. Failures are
/// swallowed on purpose: cries are OGG files, which some browsers (Safari)
/// and devices cannot play, and a missing cry is not worth an error.
class CryPlayer {
  AudioPlayer? _player;

  Future<void> play(String url) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(UrlSource(url));
    } catch (_) {
      // Unsupported format, no audio output or blocked autoplay: stay silent.
    }
  }

  Future<void> dispose() async => _player?.dispose();
}
