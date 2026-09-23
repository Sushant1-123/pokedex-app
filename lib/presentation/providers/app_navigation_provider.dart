import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every section of the app, in sidebar order. Each has its own route, so
/// deep links open it directly (after the launch intro).
enum AppDestination {
  specimenIndex('/', 'Specimen Stream'),
  telemetry('/diagnostics', 'Diagnostic Matrix'),
  evolution('/evolution', 'Evolution Engine'),
  types('/types', 'Type Spectra'),
  habitats('/habitats', 'Habitat Radar'),
  compare('/compare', 'Compare Lab'),
  abilities('/abilities', 'Ability Codex'),
  saved('/saved', 'Saved Records');

  const AppDestination(this.path, this.label);

  final String path;
  final String label;

  /// Destinations in the mobile bottom bar; the rest live under "More".
  static const primary = [specimenIndex, evolution, types];

  static AppDestination fromPath(String? path) => switch (path) {
    // Earlier builds linked the diagnostics screen as /telemetry.
    '/telemetry' => telemetry,
    _ => values.firstWhere(
      (destination) => destination.path == path,
      orElse: () => specimenIndex,
    ),
  };
}

class AppNavigationNotifier extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.specimenIndex;

  void select(AppDestination destination) {
    state = destination;
  }
}

final appNavigationProvider =
    NotifierProvider<AppNavigationNotifier, AppDestination>(
      AppNavigationNotifier.new,
    );
