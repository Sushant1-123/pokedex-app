import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_tokens.dart';
import '../../core/result.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/saved_records_provider.dart';

/// Heart toggle from the Stitch cards; saves the Pokemon to the field archive.
class SavedRecordButton extends ConsumerWidget {
  final PokemonSummary pokemon;
  final double size;

  const SavedRecordButton({super.key, required this.pokemon, this.size = 18});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = switch (ref.watch(savedRecordsProvider)) {
      Success<List<PokemonSummary>>(data: final records) => records.any(
        (record) => record.id == pokemon.id,
      ),
      _ => false,
    };
    return IconButton(
      onPressed: () => ref.read(savedRecordsProvider.notifier).toggle(pokemon),
      tooltip: saved ? 'Remove saved record' : 'Save record',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: size,
        color: saved ? AppColors.crimson : AppColors.textMuted,
      ),
    );
  }
}
