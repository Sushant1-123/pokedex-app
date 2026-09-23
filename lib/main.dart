import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme.dart';
import 'data/datasources/pokemon_cache.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/intro/intro_overlay.dart';
import 'presentation/providers/app_navigation_provider.dart';
import 'presentation/screens/pokemon_list_screen.dart';
import 'presentation/screens/telemetry_screen.dart';
import 'presentation/screens/saved_records_screen.dart';
import 'presentation/screens/sections/ability_codex_screen.dart';
import 'presentation/screens/sections/compare_lab_screen.dart';
import 'presentation/screens/sections/evolution_engine_screen.dart';
import 'presentation/screens/sections/habitat_radar_screen.dart';
import 'presentation/screens/sections/type_spectra_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });

  // Open the persistent (Hive) cache once, before the app starts, so every
  // screen can read/write it synchronously through the repository.
  await Hive.initFlutter();
  final cache = PokemonCache();
  await cache.init();

  runApp(
    ProviderScope(
      overrides: [pokemonCacheProvider.overrideWithValue(cache)],
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
      theme: AppTheme.dark(),
      // The launch intro sits above the Navigator, so it plays once per app
      // launch / page load over whichever route opens first (deep links
      // included) and never on in-app navigation.
      builder: (context, child) => IntroGate(child: child!),
      initialRoute: AppDestination.specimenIndex.path,
      onGenerateRoute: (settings) {
        final destination = AppDestination.fromPath(settings.name);
        final screen = switch (destination) {
          AppDestination.specimenIndex => const PokemonListScreen(),
          AppDestination.telemetry => const TelemetryScreen(),
          AppDestination.evolution => const EvolutionEngineScreen(),
          AppDestination.types => const TypeSpectraScreen(),
          AppDestination.habitats => const HabitatRadarScreen(),
          AppDestination.compare => const CompareLabScreen(),
          AppDestination.abilities => const AbilityCodexScreen(),
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
