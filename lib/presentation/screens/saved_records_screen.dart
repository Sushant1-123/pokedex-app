import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_tokens.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/saved_records_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/field_shell.dart';
import '../widgets/pokemon_card.dart';
import 'pokemon_detail_screen.dart';

class SavedRecordsScreen extends ConsumerWidget {
  const SavedRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(savedRecordsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final padding = Breakpoints.pagePaddingFor(width);
    final columns = Breakpoints.columnsFor(width);
    final gap = Breakpoints.gridGapFor(width);

    return FieldShell(
      active: AppDestination.saved,
      child: switch (result) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failure(:final message) => ErrorView(
          message: message,
          onRetry: () => ref.read(savedRecordsProvider.notifier).load(),
        ),
        Success(data: final records) =>
          records.isEmpty
              ? const _EmptySavedRecords()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth =
                        (constraints.maxWidth -
                            padding * 2 -
                            gap * (columns - 1)) /
                        columns;
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            AppSpacing.xl,
                            padding,
                            AppSpacing.xl,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _SavedHeading(),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            0,
                            padding,
                            padding,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final pokemon = records[index];
                              return PokemonCard(
                                key: ValueKey(pokemon.id),
                                index: index,
                                pokemon: pokemon,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PokemonDetailScreen(
                                      pokemonId: pokemon.id,
                                      heroTag: 'pokemon-image-${pokemon.id}',
                                      initialImageUrl: pokemon.imageUrl,
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: records.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: gap,
                                  crossAxisSpacing: gap,
                                  mainAxisExtent: pokemonCardExtent(cellWidth),
                                ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
      },
    );
  }
}

class _SavedHeading extends StatelessWidget {
  const _SavedHeading();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SAVED RECORDS',
        style: AppTypography.label.copyWith(color: AppColors.cyan),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text('Personal Field Archive', style: AppTypography.headline),
    ],
  );
}

class _EmptySavedRecords extends StatelessWidget {
  const _EmptySavedRecords();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PokeBallMark(glow: AppColors.crimson),
          const SizedBox(height: AppSpacing.lg),
          const Text('NO SAVED RECORDS', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tap the heart on a specimen to add it to the field archive.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.cyan,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            child: const Text('OPEN SPECIMEN INDEX'),
          ),
        ],
      ),
    ),
  );
}
