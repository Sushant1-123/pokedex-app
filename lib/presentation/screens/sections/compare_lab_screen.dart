import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_tokens.dart';
import '../../../data/models/pokemon_detail.dart';
import '../../providers/app_navigation_provider.dart';
import '../../providers/section_providers.dart';
import '../../widgets/detail/detail_sections.dart';
import '../../widgets/error_view.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/panel.dart';
import '../../widgets/pokemon_card.dart';
import '../../widgets/pokemon_image.dart';
import '../../widgets/section_page.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/type_badge.dart';

/// One colour per compare slot, so bars and radar polygons are easy to tell
/// apart.
const _slotColors = [AppColors.cyan, AppColors.crimson, AppColors.warning];

const _statOrder = [
  'hp',
  'attack',
  'defense',
  'special-attack',
  'special-defense',
  'speed',
];

int _statOf(PokemonDetail detail, String name) =>
    detail.stats.where((s) => s.name == name).firstOrNull?.base ?? 0;

/// Side-by-side comparison of 2-3 Pokemon.
class CompareLabScreen extends ConsumerWidget {
  const CompareLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(compareProvider);
    final notifier = ref.read(compareProvider.notifier);
    final ready = [
      for (final p in picks)
        if (p is PickReady) p,
    ];
    final full = picks.length >= CompareNotifier.maxPicks;
    return SectionPage(
      destination: AppDestination.compare,
      title: 'Compare Lab',
      subtitle:
          'Pick up to ${CompareNotifier.maxPicks} Pokémon to compare stats, '
          'totals and defensive matchups side by side.',
      children: [
        Panel(
          child: full
              ? const Text(
                  'The lab holds ${CompareNotifier.maxPicks} specimens. Remove '
                  'one to add another.',
                  style: AppTypography.bodySmall,
                )
              : PokemonPicker(
                  hint: 'Add a Pokémon to compare',
                  onPick: (entry) => notifier.add(entry.id),
                ),
        ),
        if (picks.isEmpty)
          const EmptyState(
            title: 'Compare Lab Is Empty',
            message:
                'Search above, or use "Compare" on any detail screen to '
                'bring a Pokémon here.',
          )
        else ...[
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              for (var i = 0; i < picks.length; i++)
                SizedBox(
                  width: 240,
                  child: _SlotCard(
                    pick: picks[i],
                    color: _slotColors[i],
                    onRemove: () => notifier.remove(picks[i].id),
                    onRetry: () => notifier.retry(picks[i].id),
                  ),
                ),
            ],
          ),
          if (ready.length >= 2) ...[
            _StatComparison(picks: ready, slots: picks),
            _DefenseComparison(picks: ready, slots: picks),
          ] else
            const EmptyState(
              title: 'Add Another Specimen',
              message: 'Comparisons appear once two Pokémon are loaded.',
            ),
        ],
      ],
    );
  }
}

Color _colorFor(List<ComparePick> all, PickReady pick) =>
    _slotColors[all.indexWhere((p) => p.id == pick.id)];

class _SlotCard extends StatelessWidget {
  final ComparePick pick;
  final Color color;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _SlotCard({
    required this.pick,
    required this.color,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Panel(
    glow: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: AppSpacing.md,
              height: AppSpacing.md,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                dexNumber(pick.id),
                style: AppTypography.numeric.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
        switch (pick) {
          PickLoading() => const SectionSkeleton(lines: 4),
          PickFailed(:final message) => SectionError(
            message: message,
            onRetry: onRetry,
          ),
          PickReady(:final detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 140,
                child: GridBackground(
                  tint: color,
                  child: InkWell(
                    onTap: () => openPokemonDetail(context, detail.id),
                    child: PokemonImage(url: detail.imageUrl, accent: color),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(titleCase(detail.name), style: AppTypography.title),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs + 2,
                children: [
                  for (final type in detail.types) TypePill(type: type),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${detail.baseStatTotal}',
                      style: AppTypography.metric.copyWith(color: color),
                    ),
                    const TextSpan(text: '  BST'),
                  ],
                ),
                style: AppTypography.caption,
              ),
            ],
          ),
        },
      ],
    ),
  );
}

class _StatComparison extends StatelessWidget {
  final List<PickReady> picks;
  final List<ComparePick> slots;
  const _StatComparison({required this.picks, required this.slots});

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'BASE STAT OVERLAY',
          icon: Icons.bar_chart_rounded,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final bars = Column(
              children: [
                for (final stat in _statOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            statLabel(stat),
                            style: AppTypography.label,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              for (final pick in picks)
                                _OverlayBar(
                                  value: _statOf(pick.detail, stat),
                                  color: _colorFor(slots, pick),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
            final radar = SizedBox.square(
              dimension: AppSizes.radarChart,
              child: CustomPaint(
                painter: _RadarPainter(
                  series: [
                    for (final pick in picks)
                      (
                        color: _colorFor(slots, pick),
                        values: [
                          for (final stat in _statOrder)
                            _statOf(pick.detail, stat),
                        ],
                      ),
                  ],
                ),
              ),
            );
            return constraints.maxWidth >= 640
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bars),
                      const SizedBox(width: AppSpacing.xxl),
                      radar,
                    ],
                  )
                : Column(
                    children: [
                      bars,
                      Center(child: radar),
                    ],
                  );
          },
        ),
      ],
    ),
  );
}

class _OverlayBar extends StatelessWidget {
  final int value;
  final Color color;
  const _OverlayBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: (value / 255).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppTypography.numeric.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

/// Spider chart of the six base stats, one polygon per Pokemon.
class _RadarPainter extends CustomPainter {
  final List<({Color color, List<int> values})> series;
  const _RadarPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - AppSpacing.xxl;
    final axes = _statOrder.length;
    Offset point(int axis, double fraction) {
      final angle = -math.pi / 2 + axis * 2 * math.pi / axes;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
    }

    final grid = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke;
    for (final ring in [.25, .5, .75, 1.0]) {
      canvas.drawPath(
        Path()
          ..addPolygon([for (var a = 0; a < axes; a++) point(a, ring)], true),
        grid,
      );
    }
    for (var a = 0; a < axes; a++) {
      canvas.drawLine(center, point(a, 1), grid);
      final painter = TextPainter(
        text: TextSpan(
          text: statLabel(_statOrder[a]),
          style: AppTypography.caption,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        point(a, 1.18) - Offset(painter.width / 2, painter.height / 2),
      );
    }
    for (final s in series) {
      final path = Path()
        ..addPolygon([
          for (var a = 0; a < axes; a++)
            point(a, (s.values[a] / 200).clamp(0.05, 1.0)),
        ], true);
      canvas
        ..drawPath(path, Paint()..color = s.color.withValues(alpha: .18))
        ..drawPath(
          path,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.series != series;
}

class _DefenseComparison extends StatelessWidget {
  final List<PickReady> picks;
  final List<ComparePick> slots;
  const _DefenseComparison({required this.picks, required this.slots});

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'DEFENSIVE MATCHUPS',
          icon: Icons.shield_outlined,
        ),
        Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.lg,
          children: [
            for (final pick in picks)
              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleCase(pick.detail.name),
                      style: AppTypography.titleSmall.copyWith(
                        color: _colorFor(slots, pick),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('WEAK TO', style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      pick.defenses.weaknesses.isEmpty
                          ? 'Nothing'
                          : pick.defenses.weaknesses
                                .map(
                                  (m) =>
                                      '${titleCase(m.type)} '
                                      '${formatMultiplier(m.multiplier)}',
                                )
                                .join(', '),
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'RESISTS / IMMUNE',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        for (final t in pick.defenses.immunities)
                          '${titleCase(t)} 0×',
                        for (final m in pick.defenses.resistances)
                          '${titleCase(m.type)} '
                              '${formatMultiplier(m.multiplier)}',
                      ].join(', ').ifEmpty('Nothing'),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
