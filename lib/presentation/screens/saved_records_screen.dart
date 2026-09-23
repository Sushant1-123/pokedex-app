import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= Breakpoints.desktop;
    final columns = Breakpoints.columnsFor(width);
    final cardAspectRatio = width >= Breakpoints.desktop
        ? 0.94
        : width >= Breakpoints.tablet
        ? 0.88
        : 0.82;

    return FieldShell(
      active: AppDestination.saved,
      child: switch (result) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failure(message: final message) => ErrorView(
          message: message,
          onRetry: () => ref.read(savedRecordsProvider.notifier).load(),
        ),
        Success(data: final records) =>
          records.isEmpty
              ? const _EmptySavedRecords()
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 32 : 18,
                        24,
                        isDesktop ? 32 : 18,
                        28,
                      ),
                      sliver: const SliverToBoxAdapter(child: _SavedHeading()),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 18,
                        vertical: 4,
                      ),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final pokemon = records[index];
                          return PokemonCard(
                            pokemon: pokemon,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PokemonDetailScreen(
                                  nameOrId: pokemon.name,
                                  heroTag: 'pokemon-image-${pokemon.id}',
                                ),
                              ),
                            ),
                          );
                        }, childCount: records.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: cardAspectRatio,
                        ),
                      ),
                    ),
                  ],
                ),
      },
    );
  }
}

class _SavedHeading extends StatelessWidget {
  const _SavedHeading();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SAVED RECORDS',
        style: TextStyle(
          color: AppTheme.signal,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'PERSONAL FIELD ARCHIVE',
        style: TextStyle(
          color: AppTheme.paper,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _EmptySavedRecords extends StatelessWidget {
  const _EmptySavedRecords();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bookmark_border_rounded,
            size: 42,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 16),
          const Text(
            'NO SAVED RECORDS',
            style: TextStyle(
              color: AppTheme.paper,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bookmark a specimen to add it to the field archive.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.signal,
              side: const BorderSide(color: AppTheme.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: const Text('OPEN SPECIMEN INDEX'),
          ),
        ],
      ),
    ),
  );
}
