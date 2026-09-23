import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/telemetry_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/field_shell.dart';

class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(telemetryProvider);
    return FieldShell(
      active: AppDestination.telemetry,
      onRefresh: () => ref.read(telemetryProvider.notifier).load(),
      child: switch (result) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failure(message: final message) => ErrorView(
            message: message,
            onRetry: () => ref.read(telemetryProvider.notifier).load(),
          ),
        Success(data: final telemetry) => _TelemetryContent(data: telemetry),
      },
    );
  }
}

class _TelemetryContent extends StatelessWidget {
  final TelemetryData data;
  const _TelemetryContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedTypes = data.typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sortedTypes.isEmpty ? 1 : sortedTypes.first.value;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= Breakpoints.desktop;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 18, 24, isDesktop ? 32 : 18, 28),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TelemetryHeading(),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                        label: 'LOADED SPECIMENS',
                        value: '${data.totalSpecimens}'),
                    _Metric(
                        label: 'TYPE CLASSES',
                        value: '${data.typeCounts.length}'),
                    _Metric(
                        label: 'AVG HEIGHT',
                        value: '${data.averageHeightM.toStringAsFixed(1)} m'),
                    _Metric(
                        label: 'AVG WEIGHT',
                        value: '${data.averageWeightKg.toStringAsFixed(1)} kg'),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionLabel(label: 'TYPE DISTRIBUTION'),
                const SizedBox(height: 12),
                if (sortedTypes.isEmpty)
                  const Text('NO LOADED TELEMETRY',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12))
                else
                  ...sortedTypes.map((entry) => _TypeReading(
                        type: entry.key,
                        count: entry.value,
                        maximum: maxCount,
                      )),
                const SizedBox(height: 24),
                const _SectionLabel(label: 'AVERAGE BASE STATS'),
                const SizedBox(height: 12),
                ...data.averageBaseStats.entries.map((entry) => _StatReading(
                      name: entry.key,
                      value: entry.value,
                    )),
                const SizedBox(height: 24),
                const Text(
                  'TELEMETRY IS DERIVED FROM THE CURRENT POKEAPI SPECIMEN INDEX.',
                  style: TextStyle(
                      color: AppTheme.muted, fontSize: 10, letterSpacing: .6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TelemetryHeading extends StatelessWidget {
  const _TelemetryHeading();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TELEMETRY',
              style: TextStyle(
                  color: AppTheme.signal,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
          SizedBox(height: 8),
          Text('SPECIMEN FIELD READINGS',
              style: TextStyle(
                  color: AppTheme.paper,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.panel,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.paper,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.muted, fontSize: 10, letterSpacing: 1)),
        ]),
      );
}

class _TypeReading extends StatelessWidget {
  final String type;
  final int count;
  final int maximum;
  const _TypeReading(
      {required this.type, required this.count, required this.maximum});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
            width: 90,
            child: Text(type.toUpperCase(),
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                minHeight: 8,
                value: count / maximum,
                backgroundColor: AppTheme.panelRaised,
                color: color),
          ),
        ),
        SizedBox(
            width: 42,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.paper, fontSize: 11))),
      ]),
    );
  }
}

class _StatReading extends StatelessWidget {
  final String name;
  final double value;
  const _StatReading({required this.name, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(name.replaceAll('-', ' ').toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
          Expanded(
            child: LinearProgressIndicator(
                minHeight: 8,
                value: (value / 255).clamp(0.0, 1.0),
                backgroundColor: AppTheme.panelRaised,
                color: AppTheme.signal),
          ),
          SizedBox(
              width: 42,
              child: Text(value.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppTheme.paper, fontSize: 11))),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 5, height: 5, color: AppTheme.signal),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ]);
}
