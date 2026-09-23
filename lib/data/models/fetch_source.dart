/// Where a repository result came from. Drives the latency readout, which
/// shows either "CACHE" or the measured duration of the network request.
sealed class FetchSource {
  const FetchSource();

  /// Combines the sources of results fetched in parallel: a cache hit only if
  /// every part was cached, otherwise the slowest network request.
  static FetchSource combine(Iterable<FetchSource> sources) {
    Duration? slowest;
    for (final source in sources) {
      if (source case NetworkFetch(:final latency)) {
        if (slowest == null || latency > slowest) slowest = latency;
      }
    }
    return slowest == null ? const CacheHit() : NetworkFetch(slowest);
  }
}

final class CacheHit extends FetchSource {
  const CacheHit();
}

final class NetworkFetch extends FetchSource {
  final Duration latency;
  const NetworkFetch(this.latency);
}
