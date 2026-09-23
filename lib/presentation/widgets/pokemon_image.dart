import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../intro/intro_painters.dart';

/// Network artwork with a designed placeholder when PokeAPI has no image
/// ([url] is null) or it fails to load, so there is never a broken image.
class PokemonImage extends StatelessWidget {
  final String? url;
  final Color accent;
  final BoxFit fit;
  final double? height;
  final FilterQuality filterQuality;

  const PokemonImage({
    super.key,
    required this.url,
    required this.accent,
    this.fit = BoxFit.contain,
    this.height,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return ArtworkPlaceholder(height: height);
    return Image.network(
      url,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: accent),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          ArtworkPlaceholder(height: height),
    );
  }
}

class ArtworkPlaceholder extends StatelessWidget {
  final double? height;
  const ArtworkPlaceholder({super.key, this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      // Scales down to fit small slots such as evolution thumbnails.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: .35,
              child: SizedBox.square(
                dimension: height == null ? 36 : height! * .3,
                child: const CustomPaint(painter: PokeBallPainter()),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'NO ARCHIVE IMAGE',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
