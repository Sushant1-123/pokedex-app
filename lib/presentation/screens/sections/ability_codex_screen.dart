import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_tokens.dart';
import '../../../core/result.dart';
import '../../../core/theme.dart';
import '../../../data/models/ability.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/panel.dart';
import '../../widgets/pokemon_card.dart';
import '../../widgets/section_page.dart';

/// Searchable list of every ability, with effect text and the Pokemon that
/// have it.
class AbilityCodexScreen extends ConsumerWidget {
  const AbilityCodexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abilityCodexProvider);
    final notifier = ref.read(abilityCodexProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final list = switch (state.index) {
      Loading() => const Panel(child: SectionSkeleton(lines: 8)),
      Failure(:final message) => ErrorView(
        message: message,
        onRetry: notifier.load,
      ),
      Success() => _AbilityList(
        matches: notifier.matches,
        selected: state.selection?.name,
        onSelect: notifier.select,
      ),
    };
    final detail = switch (state.selection) {
      null => const EmptyState(
        title: 'No Ability Selected',
        message: 'Search the codex and pick an ability to read its effect.',
      ),
      (:final name, detail: Loading()) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: titleCase(name).toUpperCase()),
            const SectionSkeleton(lines: 5),
          ],
        ),
      ),
      (:final name, detail: Failure(:final message)) => ErrorView(
        message: message,
        onRetry: () => notifier.select(name),
      ),
      (name: _, detail: Success(:final data)) => _AbilityDetail(ability: data),
    };
    return SectionPage(
      destination: AppDestination.abilities,
      title: 'Ability Codex',
      subtitle: 'Every ability in PokeAPI, with its effect and who has it.',
      onRefresh: notifier.load,
      children: [
        TextField(
          onChanged: notifier.setQuery,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            hintText: 'Search abilities, e.g. blaze',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: list),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(flex: 6, child: detail),
            ],
          )
        else ...[
          detail,
          list,
        ],
      ],
    );
  }
}

class _AbilityList extends StatelessWidget {
  final List<AbilityEntry> matches;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _AbilityList({
    required this.matches,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const EmptyState(
        title: 'No Ability Found',
        message: 'Try a different spelling.',
      );
    }
    return Panel(
      padding: const EdgeInsets.all(AppSpacing.xs),
      // ListTiles paint on the nearest Material, not on the Panel's colour.
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final ability = matches[i];
              final active = ability.name == selected;
              return ListTile(
                dense: true,
                selected: active,
                selectedTileColor: AppColors.crimson.withValues(alpha: .15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                onTap: () => onSelect(ability.name),
                title: Text(
                  titleCase(ability.name),
                  style: AppTypography.titleSmall.copyWith(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AbilityDetail extends StatelessWidget {
  final AbilityDetail ability;
  const _AbilityDetail({required this.ability});

  @override
  Widget build(BuildContext context) => Panel(
    glow: AppColors.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: titleCase(ability.name).toUpperCase(),
          icon: Icons.auto_stories_outlined,
          trailing: ability.generation == null
              ? null
              : Text('GEN ${ability.generation}', style: AppTypography.label),
        ),
        Text(
          ability.shortEffect ?? 'No effect text in PokeAPI yet.',
          style: AppTypography.titleSmall,
        ),
        if (ability.effect case final String effect
            when effect != ability.shortEffect) ...[
          const SizedBox(height: AppSpacing.md),
          Text(effect, style: AppTypography.body),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'POKÉMON WITH THIS ABILITY (${ability.pokemon.length})',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final holder in ability.pokemon)
              ActionChip(
                onPressed: () => openPokemonDetail(context, holder.pokemon.id),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: holder.isHidden
                      ? AppColors.crimson.withValues(alpha: .6)
                      : AppColors.border,
                ),
                label: Text(
                  holder.isHidden
                      ? '${titleCase(holder.pokemon.name)} · HIDDEN'
                      : titleCase(holder.pokemon.name),
                  style: AppTypography.caption.copyWith(
                    color: holder.isHidden
                        ? AppColors.crimson
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
