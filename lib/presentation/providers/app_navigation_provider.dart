import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDestination {
  specimenIndex('/', 'Specimen index'),
  telemetry('/telemetry', 'Telemetry'),
  saved('/saved', 'Saved records');

  const AppDestination(this.path, this.label);

  final String path;
  final String label;

  static AppDestination fromPath(String? path) {
    return AppDestination.values.firstWhere(
      (destination) => destination.path == path,
      orElse: () => AppDestination.specimenIndex,
    );
  }
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
