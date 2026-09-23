import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/pokemon_detail.dart';
import '../../data/models/pokemon_summary.dart';
import '../providers/pokemon_detail_provider.dart';
import '../widgets/type_badge.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/error_view.dart';
import '../widgets/stat_bar.dart';
import '../widgets/pokemon_image.dart';
import '../widgets/saved_record_button.dart';

class PokemonDetailScreen extends ConsumerWidget {
  final String nameOrId;
  final String? heroTag;
  const PokemonDetailScreen({super.key, required this.nameOrId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(pokemonDetailProvider(nameOrId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SPECIMEN TELEMETRY',
                    style: TextStyle(
                      color: AppTheme.paper,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'RECORD / ${nameOrId.toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.signal,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (result) {
                Loading() => const PokemonDetailSkeleton(),
                Failure(message: final msg) => ErrorView(
                  message: msg,
                  onRetry: () =>
                      ref.read(pokemonDetailProvider(nameOrId).notifier).load(),
                ),
                Success(data: final detail) => LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= Breakpoints.tablet;
                    final accent = detail.types.isNotEmpty
                        ? colorForType(detail.types.first)
                        : AppTheme.signal;
                    final identity = _Identity(
                      detail: detail,
                      heroTag: heroTag,
                      accent: accent,
                    );
                    final readings = _Readings(detail: detail, accent: accent);
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 32 : 18),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: identity),
                                const SizedBox(width: 24),
                                Expanded(child: readings),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                identity,
                                const SizedBox(height: 28),
                                readings,
                              ],
                            ),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final PokemonDetail detail;
  final String? heroTag;
  final Color accent;
  const _Identity({
    required this.detail,
    required this.heroTag,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 330,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.panel,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Text(
                'VISUAL ARCHIVE / 01',
                style: TextStyle(color: accent, fontSize: 10, letterSpacing: 1),
              ),
            ),
            Center(
              child: Hero(
                tag: heroTag ?? 'pokemon-image-${detail.id}',
                child: PokemonImage(
                  pokemonId: detail.id,
                  accent: accent,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        '#${detail.id.toString().padLeft(3, '0')}',
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Text(
              _titleCase(detail.name),
              style: const TextStyle(
                color: AppTheme.paper,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SavedRecordButton(
            pokemon: PokemonSummary(
              id: detail.id,
              name: detail.name,
              imageUrl: detail.imageUrl,
              types: detail.types,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        children: [
          for (var i = 0; i < detail.types.length; i++)
            TypeBadge(type: detail.types[i], index: i),
        ],
      ),
    ],
  );
}

class _Readings extends StatelessWidget {
  final PokemonDetail detail;
  final Color accent;
  const _Readings({required this.detail, required this.accent});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel(label: 'PHYSICAL READINGS'),
      const SizedBox(height: 10),
      Row(
        children: [
          _MetricChip(label: 'HEIGHT', value: '${detail.heightM} m'),
          const SizedBox(width: 10),
          _MetricChip(label: 'WEIGHT', value: '${detail.weightKg} kg'),
        ],
      ),
      const SizedBox(height: 28),
      const _SectionLabel(label: 'BASE STAT TELEMETRY'),
      const SizedBox(height: 10),
      ...detail.stats.map(
        (stat) => StatBar(
          label: stat.name.replaceAll('-', ' '),
          value: stat.base,
          color: accent,
        ),
      ),
      const SizedBox(height: 24),
      const _SectionLabel(label: 'KNOWN ABILITIES'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: detail.abilities
            .map(
              (ability) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.panelRaised,
                  border: Border.all(color: AppTheme.line),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _titleCase(ability.replaceAll('-', ' ')),
                  style: const TextStyle(color: AppTheme.paper, fontSize: 11),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 5, height: 5, color: AppTheme.signal),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          color: AppTheme.panelRaised,
          border: Border.fromBorderSide(BorderSide(color: AppTheme.line)),
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.paper,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.muted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
