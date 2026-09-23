import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme.dart';
import 'data/datasources/pokemon_cache.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/app_navigation_provider.dart';
import 'presentation/screens/pokemon_list_screen.dart';
import 'presentation/screens/telemetry_screen.dart';
import 'presentation/screens/saved_records_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Open the persistent (Hive) cache once, before the app starts, so every
  // screen can read/write it synchronously through the repository.
  final cache = PokemonCache();
  await cache.init();

  runApp(
    ProviderScope(
      overrides: [
        pokemonCacheProvider.overrideWithValue(cache),
      ],
      child: const PokedexApp(),
    ),
  );
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokedex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      initialRoute: AppDestination.specimenIndex.path,
      onGenerateRoute: (settings) {
        final destination = AppDestination.fromPath(settings.name);
        final screen = switch (destination) {
          AppDestination.specimenIndex => const PokemonListScreen(),
          AppDestination.telemetry => const TelemetryScreen(),
          AppDestination.saved => const SavedRecordsScreen(),
        };
        return MaterialPageRoute(
          settings: RouteSettings(name: destination.path),
          builder: (_) => screen,
        );
      },
    );
  }
}
