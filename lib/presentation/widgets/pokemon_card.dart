import 'package:flutter/material.dart';
import '../../data/models/pokemon_summary.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'pokemon_image.dart';
import 'saved_record_button.dart';

class PokemonCard extends StatelessWidget {
  final PokemonSummary pokemon;
  final VoidCallback onTap;
  const PokemonCard({super.key, required this.pokemon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = pokemon.types.isNotEmpty
        ? colorForType(pokemon.types.first)
        : AppTheme.muted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              border: Border(top: BorderSide(color: accent, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('FIELD SAMPLE',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.muted,
                              letterSpacing: 1)),
                    ),
                    Text('#${pokemon.id.toString().padLeft(3, '0')}',
                        style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w700)),
                    SavedRecordButton(pokemon: pokemon, color: accent),
                  ],
                ),
                Expanded(
                  child: Hero(
                    tag: 'pokemon-image-${pokemon.id}',
                    child: PokemonImage(
                      pokemonId: pokemon.id,
                      accent: accent,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Text(
                  _capitalize(pokemon.name),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.paper),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: pokemon.types
                      .map((type) => _TypeLabel(type: type))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TypeLabel extends StatelessWidget {
  final String type;
  const _TypeLabel({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(type.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}
