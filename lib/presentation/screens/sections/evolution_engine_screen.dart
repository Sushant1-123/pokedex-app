import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_tokens.dart';
import '../../../core/result.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../../widgets/detail/detail_sections.dart';
import '../../widgets/panel.dart';
import '../../widgets/pokemon_card.dart';
import '../../widgets/section_page.dart';

/// Search any Pokemon and see its whole evolution tree.
class EvolutionEngineScreen extends ConsumerWidget {
  const EvolutionEngineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(evolutionEngineProvider);
    final engine = ref.read(evolutionEngineProvider.notifier);
    return SectionPage(
      destination: AppDestination.evolution,
      title: 'Evolution Engine',
      subtitle:
          'Trace any species through its full evolution tree, with the '
          'level, item, friendship or trade that triggers each stage.',
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PokemonPicker(
                hint: 'Search a Pokémon to trace',
                onPick: engine.open,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final pick in evolutionQuickPicks)
                    OutlinedButton(
                      onPressed: () => engine.open(pick),
                      child: Text(titleCase(pick.name)),
                    ),
                  FilledButton.icon(
                    onPressed: engine.openRandom,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('Random chain'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (lookup == null)
          const EmptyState(
            title: 'No Chain Selected',
            message:
                'Search for a Pokémon, pick one above or roll a random '
                'chain.',
          )
        else
          EvolutionPanel(
            evolution: switch (lookup) {
              Success(:final data) => Success(data.chain),
              Failure(:final message) => Failure(message),
              Loading() => const Loading(),
            },
            currentSpeciesId: switch (lookup) {
              Success(:final data) => data.entry.id,
              _ => -1,
            },
            linkCurrent: true,
            onOpen: (id) => openPokemonDetail(context, id),
            onRetry: engine.retry,
          ),
      ],
    );
  }
}
