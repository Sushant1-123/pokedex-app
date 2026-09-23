import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/saved_records_provider.dart';

class SavedRecordButton extends ConsumerWidget {
  final PokemonSummary pokemon;
  final Color color;

  const SavedRecordButton({
    super.key,
    required this.pokemon,
    this.color = AppTheme.muted,
  });

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
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 18,
        color: saved ? AppTheme.signal : color,
      ),
    );
  }
}
