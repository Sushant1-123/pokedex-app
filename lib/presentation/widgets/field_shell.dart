import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../intro/intro_painters.dart';
import '../providers/app_navigation_provider.dart';
import '../providers/node_status_provider.dart';
import 'status_readouts.dart';

/// App chrome: a header with the Poke Ball logo, then the navigation for
/// the screen size — the Stitch sidebar on desktop, a rail on tablet, and a
/// bottom bar with a "More" sheet on mobile.
///
/// [bottomBar] (e.g. the phone pager) is pinned under the content, above
/// the mobile navigation bar and inside the safe area.
class FieldShell extends ConsumerWidget {
  final AppDestination active;
  final Widget child;
  final VoidCallback? onRefresh;
  final Widget? bottomBar;

  const FieldShell({
    super.key,
    required this.active,
    required this.child,
    this.onRefresh,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= Breakpoints.desktop;
    final isTablet = !isDesktop && width >= Breakpoints.tablet;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(onRefresh: onRefresh),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop) _Sidebar(active: active),
                  if (isTablet) _Rail(active: active),
                  Expanded(child: child),
                ],
              ),
            ),
            ?bottomBar,
            if (!isDesktop && !isTablet) _BottomNav(active: active),
          ],
        ),
      ),
    );
  }
}

void navigateToDestination(
  BuildContext context,
  WidgetRef ref,
  AppDestination destination,
) {
  ref.read(appNavigationProvider.notifier).select(destination);
  if (ModalRoute.of(context)?.settings.name == destination.path) return;
  Navigator.of(context).pushNamed(destination.path);
}

IconData iconFor(AppDestination destination) => switch (destination) {
  AppDestination.specimenIndex => Icons.grid_view_rounded,
  AppDestination.telemetry => Icons.insights_rounded,
  AppDestination.evolution => Icons.account_tree_outlined,
  AppDestination.types => Icons.palette_outlined,
  AppDestination.habitats => Icons.explore_outlined,
  AppDestination.compare => Icons.compare_arrows_rounded,
  AppDestination.abilities => Icons.auto_stories_outlined,
  AppDestination.saved => Icons.favorite_border_rounded,
};

class _Header extends StatelessWidget {
  final VoidCallback? onRefresh;
  const _Header({this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 30,
          child: CustomPaint(painter: PokeBallPainter()),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POKÉDEX TELEMETRY', style: AppTypography.title),
              Text(
                'BIO-ANALYTICAL FIELD SYSTEM',
                style: AppTypography.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Sync specimen index',
            icon: const Icon(Icons.sync_rounded, color: AppColors.textMuted),
          ),
      ],
    ),
  );
}

/// Desktop sidebar from the Stitch frame: terminal status on top, the
/// sections with a crimson active item, and a real cache/latency readout
/// at the bottom.
class _Sidebar extends ConsumerWidget {
  final AppDestination active;
  const _Sidebar({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(nodeStatusProvider);
    final online = status.link == NodeLink.synchronized;
    return Container(
      width: 248,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBox(
            children: [
              const Expanded(
                child: Text('TERMINAL STATUS', style: AppTypography.caption),
              ),
              Text(
                online ? 'SYNCHRONIZED' : 'OFFLINE',
                style: AppTypography.caption.copyWith(
                  color: online ? AppColors.cyan : AppColors.crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              children: [
                for (final destination in AppDestination.values)
                  _SidebarItem(
                    icon: iconFor(destination),
                    label: destination.label,
                    active: destination == active,
                    onTap: () =>
                        navigateToDestination(context, ref, destination),
                  ),
              ],
            ),
          ),
          _StatusBox(
            vertical: true,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CACHED RESPONSES',
                      style: AppTypography.caption,
                    ),
                  ),
                  Text(
                    '${status.cacheEntries}',
                    style: AppTypography.numeric.copyWith(
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Expanded(
                    child: Text('LAST REQUEST', style: AppTypography.caption),
                  ),
                  Text(
                    switch (status.lastLatency) {
                      final Duration latency => '${latency.inMilliseconds}ms',
                      null => '—',
                    },
                    style: AppTypography.numeric.copyWith(
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'DATA SOURCE · POKEAPI.CO',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final List<Widget> children;
  final bool vertical;
  const _StatusBox({required this.children, this.vertical = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.container,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    child: vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : Row(children: children),
  );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Material(
      color: active ? AppColors.crimson : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Tablet navigation rail: every section as an icon with a short label.
class _Rail extends ConsumerWidget {
  final AppDestination active;
  const _Rail({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: 92,
    decoration: const BoxDecoration(
      color: AppColors.surfaceSunken,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        for (final destination in AppDestination.values)
          _NavTile(
            icon: iconFor(destination),
            label: destination.label,
            active: destination == active,
            onTap: () => navigateToDestination(context, ref, destination),
          ),
      ],
    ),
  );
}

/// Mobile bottom bar: the three primary sections plus "More".
class _BottomNav extends ConsumerWidget {
  final AppDestination active;
  const _BottomNav({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inMore = !AppDestination.primary.contains(active);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          for (final destination in AppDestination.primary)
            Expanded(
              child: _NavTile(
                icon: iconFor(destination),
                label: destination.label,
                active: destination == active,
                onTap: () => navigateToDestination(context, ref, destination),
              ),
            ),
          Expanded(
            child: _NavTile(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              active: inMore,
              onTap: () => showMoreSheet(context, ref, active),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the sections that don't fit the mobile bar.
Future<void> showMoreSheet(
  BuildContext context,
  WidgetRef ref,
  AppDestination active,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.container,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
  ),
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Text('MORE FIELD TOOLS', style: AppTypography.label),
          ),
          for (final destination in AppDestination.values)
            if (!AppDestination.primary.contains(destination))
              _SidebarItem(
                icon: iconFor(destination),
                label: destination.label,
                active: destination == active,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  navigateToDestination(context, ref, destination);
                },
              ),
        ],
      ),
    ),
  ),
);

/// Icon + short label, used by the rail and the bottom bar.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.hover,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.crimson : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: active ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "● ONLINE" style badge for section headers, driven by the node status.
class NodeBadge extends ConsumerWidget {
  const NodeBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnlineBadge(
    online: ref.watch(nodeStatusProvider).link == NodeLink.synchronized,
  );
}
