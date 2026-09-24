import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_tokens.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_index_entry.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/name_index_provider.dart';
import '../screens/pokemon_detail_screen.dart';
import 'error_view.dart';
import 'field_shell.dart';
import 'loading_skeleton.dart';
import 'pagination_bar.dart';
import 'panel.dart';
import 'pokemon_card.dart';

/// Opens the detail screen for Pokemon [id].
void openPokemonDetail(BuildContext context, int id) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => PokemonDetailScreen(pokemonId: id)));

/// Shared layout of the field-tool sections: shell, heading with the live
/// node badge, then [children] with generous spacing.
class SectionPage extends StatelessWidget {
  final AppDestination destination;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onRefresh;

  const SectionPage({
    super.key,
    required this.destination,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final padding = Breakpoints.pagePaddingFor(
      MediaQuery.sizeOf(context).width,
    );
    return FieldShell(
      active: destination,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  destination.label.toUpperCase(),
                  style: AppTypography.label.copyWith(color: AppColors.cyan),
                ),
                const NodeBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTypography.bodySmall),
            for (final child in children) ...[
              const SizedBox(height: AppSpacing.xxl),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Designed empty state: Poke Ball mark, title and a hint.
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const EmptyState({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const PokeBallMark(glow: AppColors.cyan),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: AppTypography.title, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Search field over the cached name index with up to eight suggestions.
class PokemonPicker extends ConsumerStatefulWidget {
  final ValueChanged<PokemonIndexEntry> onPick;
  final String hint;
  const PokemonPicker({super.key, required this.onPick, required this.hint});

  @override
  ConsumerState<PokemonPicker> createState() => _PokemonPickerState();
}

class _PokemonPickerState extends ConsumerState<PokemonPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(PokemonIndexEntry entry) {
    _controller.clear();
    setState(() {});
    widget.onPick(entry);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(nameIndexProvider);
    final suggestions = ref
        .read(nameIndexProvider.notifier)
        .suggestions(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: switch (index) {
              Loading() => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              Failure() => IconButton(
                tooltip: 'Retry loading the name index',
                onPressed: ref.read(nameIndexProvider.notifier).load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              Success() => null,
            },
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Panel(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final entry in suggestions)
                    ListTile(
                      dense: true,
                      onTap: () => _pick(entry),
                      leading: Text(
                        dexNumber(entry.id),
                        style: AppTypography.numeric.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      title: Text(
                        titleCase(entry.name),
                        style: AppTypography.titleSmall,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A page of Pokemon cards with its pager, skeleton and retry.
class PokemonPageGrid extends StatelessWidget {
  final Result<PokemonPage> page;
  final ValueChanged<int> onPage;
  final VoidCallback onRetry;

  const PokemonPageGrid({
    super.key,
    required this.page,
    required this.onPage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= Breakpoints.tablet
            ? 4
            : constraints.maxWidth >= 420
            ? 3
            : 2;
        final gap = Breakpoints.gridGapFor(width);
        final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: pokemonCardExtent(cell),
        );
        return switch (page) {
          Loading() => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: delegate,
            itemCount: columns,
            itemBuilder: (_, _) => const SkeletonShimmer(
              child: SkeletonBlock(height: 0, radius: AppRadii.lg),
            ),
          ),
          Failure(:final message) => ErrorView(
            message: message,
            onRetry: onRetry,
          ),
          Success(:final data) when data.items.isEmpty => const EmptyState(
            title: 'No Specimens Recorded',
            message: 'PokeAPI lists no Pokemon here.',
          ),
          Success(:final data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: delegate,
                itemCount: data.items.length,
                itemBuilder: (context, i) => PokemonCard(
                  key: ValueKey(data.items[i].id),
                  index: i,
                  pokemon: data.items[i],
                  onTap: () => openPokemonDetail(context, data.items[i].id),
                ),
              ),
              if (data.pageCount > 1) ...[
                const SizedBox(height: AppSpacing.lg),
                PaginationBar(
                  page: data.page,
                  pageCount: data.pageCount,
                  onPage: onPage,
                ),
              ],
            ],
          ),
        };
      },
    );
  }
}
