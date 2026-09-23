import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/telemetry_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/field_shell.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/panel.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/stat_bar.dart';

class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(telemetryProvider);
    return FieldShell(
      active: AppDestination.telemetry,
      onRefresh: () => ref.read(telemetryProvider.notifier).load(),
      child: switch (result) {
        Loading() => const _TelemetrySkeleton(),
        Failure(:final message) => ErrorView(
          message: message,
          onRetry: () => ref.read(telemetryProvider.notifier).load(),
        ),
        Success(data: final telemetry) => _TelemetryContent(data: telemetry),
      },
    );
  }
}

class _TelemetrySkeleton extends StatelessWidget {
  const _TelemetrySkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.xl),
    child: Panel(child: SectionSkeleton(lines: 8)),
  );
}

class _TelemetryContent extends StatelessWidget {
  final TelemetryData data;
  const _TelemetryContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedTypes = data.typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sortedTypes.isEmpty ? 1 : sortedTypes.first.value;
    final padding = Breakpoints.pagePaddingFor(
      MediaQuery.sizeOf(context).width,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DIAGNOSTIC MATRIX',
            style: AppTypography.label.copyWith(color: AppColors.cyan),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Specimen Field Readings', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'SAMPLE: THE FIRST ${TelemetryNotifier.sampleSize} SPECIMENS OF THE '
            'POKEAPI INDEX (#0001 ONWARDS), NOT THE FULL CATALOG.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _Metric(
                label: 'SAMPLED SPECIMENS',
                value: '${data.totalSpecimens}',
              ),
              _Metric(
                label: 'TYPE CLASSES',
                value: '${data.typeCounts.length}',
              ),
              _Metric(
                label: 'AVG HEIGHT',
                value: '${data.averageHeightM.toStringAsFixed(1)} m',
              ),
              _Metric(
                label: 'AVG WEIGHT',
                value: '${data.averageWeightKg.toStringAsFixed(1)} kg',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'TYPE DISTRIBUTION',
                  icon: Icons.donut_small_outlined,
                ),
                if (sortedTypes.isEmpty)
                  const Text(
                    'NO LOADED TELEMETRY',
                    style: AppTypography.bodySmall,
                  )
                else
                  for (final entry in sortedTypes)
                    _TypeReading(
                      type: entry.key,
                      count: entry.value,
                      maximum: maxCount,
                    ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'AVERAGE BASE STATS',
                  icon: Icons.bar_chart_rounded,
                ),
                for (final entry in data.averageBaseStats.entries)
                  StatBar(
                    label: statLabel(entry.key),
                    value: entry.value.round(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.metric),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.caption),
        ],
      ),
    ),
  );
}

class _TypeReading extends StatelessWidget {
  final String type;
  final int count;
  final int maximum;
  const _TypeReading({
    required this.type,
    required this.count,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForType(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              titleCase(type).toUpperCase(),
              style: AppTypography.label.copyWith(color: color),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: count / maximum,
                backgroundColor: AppColors.track,
                color: color,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: AppTypography.numeric.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
