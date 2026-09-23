import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/result.dart';
import '../../data/models/fetch_source.dart';
import '../../data/models/pokemon_detail.dart';
import 'core_providers.dart';

class TelemetryData {
  final int totalSpecimens;
  final Map<String, int> typeCounts;
  final double averageHeightM;
  final double averageWeightKg;
  final Map<String, double> averageBaseStats;

  const TelemetryData({
    required this.totalSpecimens,
    required this.typeCounts,
    required this.averageHeightM,
    required this.averageWeightKg,
    required this.averageBaseStats,
  });

  static TelemetryData fromDetails(List<PokemonDetail> details) {
    final typeCounts = <String, int>{};
    for (final detail in details) {
      for (final type in detail.types) {
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
    }

    final averageHeight = details.isEmpty
        ? 0.0
        : details.map((detail) => detail.heightM).reduce((a, b) => a + b) /
              details.length;
    final averageWeight = details.isEmpty
        ? 0.0
        : details.map((detail) => detail.weightKg).reduce((a, b) => a + b) /
              details.length;

    final statTotals = <String, int>{};
    final statCounts = <String, int>{};
    for (final detail in details) {
      for (final stat in detail.stats) {
        statTotals[stat.name] = (statTotals[stat.name] ?? 0) + stat.base;
        statCounts[stat.name] = (statCounts[stat.name] ?? 0) + 1;
      }
    }
    final averageStats = <String, double>{};
    for (final entry in statTotals.entries) {
      averageStats[entry.key] = entry.value / statCounts[entry.key]!;
    }

    return TelemetryData(
      totalSpecimens: details.length,
      typeCounts: typeCounts,
      averageHeightM: averageHeight,
      averageWeightKg: averageWeight,
      averageBaseStats: averageStats,
    );
  }
}

/// Telemetry is computed from a fixed sample, the first page of the catalog
/// (#1 onwards), rather than everything the user has scrolled through, so it
/// never fans out into hundreds of detail requests.
class TelemetryNotifier extends Notifier<Result<TelemetryData>> {
  static const sampleSize = AppConstants.pageSize;

  @override
  Result<TelemetryData> build() {
    Future.microtask(load);
    return const Loading();
  }

  Future<void> load() async {
    state = const Loading();
    try {
      final repository = ref.read(pokemonRepositoryProvider);
      final (index, indexSource) = await repository.getPokemonIndex();
      final sample = index.where((e) => e.isBaseSpecies).take(sampleSize);
      final details = await Future.wait(
        sample.map((entry) => repository.getPokemonDetail(entry.id)),
      );
      final source = FetchSource.combine([
        indexSource,
        for (final (_, source) in details) source,
      ]);
      state = Success(
        TelemetryData.fromDetails([for (final (detail, _) in details) detail]),
        fromCache: source is CacheHit,
      );
    } catch (error) {
      state = Failure(error.toString());
    }
  }
}

final telemetryProvider =
    NotifierProvider<TelemetryNotifier, Result<TelemetryData>>(
      TelemetryNotifier.new,
    );
