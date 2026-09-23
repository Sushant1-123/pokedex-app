import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Shared error state — used by both list and detail screens so error
/// handling is consistent, per the "empty/error states must be designed" note.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.alert,
            ),
            const SizedBox(height: 16),
            Text(
              'SIGNAL LOST',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RETRY CONNECTION'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state — shown when a search query matches nothing.
class EmptyResultsView extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const EmptyResultsView({
    super.key,
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 16),
            Text(
              'NO SPECIMENS FOUND FOR "$query"',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('CLEAR SEARCH'),
            ),
          ],
        ),
      ),
    );
  }
}
