import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

class PokemonImage extends StatelessWidget {
  final int pokemonId;
  final Color accent;
  final BoxFit fit;
  final double? height;

  const PokemonImage({
    super.key,
    required this.pokemonId,
    required this.accent,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      pokemonArtworkUrl(pokemonId),
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(strokeWidth: 1, color: accent),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('POKEMON IMAGE ERROR: $error');
        return const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.muted,
          ),
        );
      },
    );
  }
}
