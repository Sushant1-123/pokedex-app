import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/pokemon_repository.dart';
import 'core_providers.dart';

/// Connection state shown in the sidebar's status boxes.
enum NodeLink { synchronized, offline }

/// Real node status: whether the last network request succeeded, how long
/// it took, and how many API responses are cached.
typedef NodeStatus = ({NodeLink link, Duration? lastLatency, int cacheEntries});

class NodeStatusNotifier extends Notifier<NodeStatus> {
  @override
  NodeStatus build() => (
    link: NodeLink.synchronized,
    lastLatency: null,
    cacheEntries: ref.read(pokemonRepositoryProvider).cacheEntryCount,
  );

  /// Called by the repository after every network request.
  void record(NetworkEvent event) {
    state = (
      link: event.latency == null ? NodeLink.offline : NodeLink.synchronized,
      lastLatency: event.latency ?? state.lastLatency,
      cacheEntries: event.cacheEntries,
    );
  }
}

final nodeStatusProvider = NotifierProvider<NodeStatusNotifier, NodeStatus>(
  NodeStatusNotifier.new,
);
