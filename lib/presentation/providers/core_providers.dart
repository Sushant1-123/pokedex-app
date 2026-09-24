import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/pokeapi_client.dart';
import '../../data/datasources/pokemon_cache.dart';
import '../../data/repositories/pokemon_repository.dart';
import 'node_status_provider.dart';

/// Simple DI providers. The cache instance is initialized once in main()
/// and overridden into the ProviderScope, so every provider below gets
/// the same already-open Hive boxes.
final pokemonCacheProvider = Provider<PokemonCache>((ref) {
  throw UnimplementedError('pokemonCacheProvider must be overridden in main()');
});

final pokeApiClientProvider = Provider<PokeApiClient>((ref) {
  final client = PokeApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  return PokemonRepository(
    client: ref.watch(pokeApiClientProvider),
    cache: ref.watch(pokemonCacheProvider),
    onNetwork: (event) => ref.read(nodeStatusProvider.notifier).record(event),
  );
});
