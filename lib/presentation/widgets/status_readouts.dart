import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../../data/models/fetch_source.dart';

/// "● ONLINE" sub-node badge; turns crimson "OFFLINE" after a failed load.
class OnlineBadge extends StatelessWidget {
  final bool online;
  const OnlineBadge({super.key, required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.crimson;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Real latency of the last load: the measured network time, or "CACHE"
/// when it was served from Hive. Never a made-up number.
class LatencyReadout extends StatelessWidget {
  final FetchSource? source;
  const LatencyReadout({super.key, required this.source});

  static String describe(FetchSource? source) => switch (source) {
    null => '—',
    CacheHit() => 'CACHE',
    NetworkFetch(:final latency) => '${latency.inMilliseconds}ms',
  };

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'LATENCY  '),
        TextSpan(
          text: describe(source),
          style: const TextStyle(color: AppColors.cyan),
        ),
      ],
    ),
    style: AppTypography.caption,
  );
}
