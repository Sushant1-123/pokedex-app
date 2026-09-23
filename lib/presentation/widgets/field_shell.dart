import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/app_navigation_provider.dart';

class FieldShell extends ConsumerWidget {
  final AppDestination active;
  final Widget child;
  final VoidCallback? onRefresh;

  const FieldShell({
    super.key,
    required this.active,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= Breakpoints.desktop;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop) _FieldSidebar(active: active),
            Expanded(
              child: Column(
                children: [
                  _Header(onRefresh: onRefresh),
                  Expanded(child: child),
                  if (!isDesktop) _MobileNav(active: active),
                ],
              ),
            ),
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

class _Header extends StatelessWidget {
  final VoidCallback? onRefresh;
  const _Header({this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.line)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.change_history_rounded,
          color: AppTheme.signal,
          size: 20,
        ),
        const SizedBox(width: 12),
        const Text(
          'POKÉDEX',
          style: TextStyle(
            color: AppTheme.paper,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.signal,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'ONLINE',
          style: TextStyle(
            color: AppTheme.signal,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Refresh specimen index',
            icon: const Icon(Icons.sync_rounded, color: AppTheme.muted),
          ),
      ],
    ),
  );
}

class _FieldSidebar extends ConsumerWidget {
  final AppDestination active;
  const _FieldSidebar({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: 220,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppTheme.line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 88, 18, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FIELD TOOLS',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _NavItem(
          icon: Icons.grid_view_rounded,
          label: AppDestination.specimenIndex.label,
          active: active == AppDestination.specimenIndex,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.specimenIndex),
        ),
        _NavItem(
          icon: Icons.bar_chart_rounded,
          label: AppDestination.telemetry.label,
          active: active == AppDestination.telemetry,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.telemetry),
        ),
        _NavItem(
          icon: Icons.bookmark_border_rounded,
          label: AppDestination.saved.label,
          active: active == AppDestination.saved,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.saved),
        ),
        const Spacer(),
        const Text(
          'API / POKEAPI',
          style: TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
        const SizedBox(height: 8),
        const Text(
          'SYNC STATUS  100%',
          style: TextStyle(color: AppTheme.signal, fontSize: 10),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppTheme.signal : AppTheme.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppTheme.paper : AppTheme.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileNav extends ConsumerWidget {
  final AppDestination active;
  const _MobileNav({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 58,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppTheme.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MobileNavItem(
          icon: Icons.grid_view_rounded,
          active: active == AppDestination.specimenIndex,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.specimenIndex),
        ),
        _MobileNavItem(
          icon: Icons.bar_chart_rounded,
          active: active == AppDestination.telemetry,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.telemetry),
        ),
        _MobileNavItem(
          icon: Icons.bookmark_border_rounded,
          active: active == AppDestination.saved,
          onTap: () =>
              navigateToDestination(context, ref, AppDestination.saved),
        ),
      ],
    ),
  );
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: active ? 'Current section' : null,
    icon: Icon(icon, color: active ? AppTheme.signal : AppTheme.muted),
  );
}
