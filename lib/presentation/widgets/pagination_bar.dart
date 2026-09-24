import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Page buttons to show, like the Stitch pager "1 2 3 … 103": the first and
/// last page plus a window of [siblings] pages either side of [current].
/// `null` marks an ellipsis; a gap of a single page shows that page instead.
List<int?> pageWindow(int current, int count, {int siblings = 1}) {
  if (count <= 1) return const [1];
  final size = siblings * 2 + 1;
  final start = (current - siblings).clamp(
    1,
    (count - size + 1).clamp(1, count),
  );
  final end = (start + size - 1).clamp(1, count);
  final pages = {1, for (var p = start; p <= end; p++) p, count}.toList()
    ..sort();
  final window = <int?>[];
  int? previous;
  for (final page in pages) {
    if (previous != null) {
      if (page - previous == 2) {
        window.add(previous + 1);
      } else if (page - previous > 2) {
        window.add(null);
      }
    }
    window.add(page);
    previous = page;
  }
  return window;
}

/// Pager for the current screen size: [MobilePaginationBar] on phones,
/// otherwise Prev / numbered pages / Next. The numbered window narrows to
/// just the current page when space is tight and the whole bar scales down
/// rather than overflow.
class PaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < Breakpoints.phone) {
      return MobilePaginationBar(
        page: page,
        pageCount: pageCount,
        onPage: onPage,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const slot = AppSizes.pagerButton + AppSpacing.xs + 2;
        final roomy =
            pageWindow(page, pageCount).length * slot +
                AppSizes.pagerNavWidth * 2 <=
            constraints.maxWidth;
        final window = pageWindow(page, pageCount, siblings: roomy ? 1 : 0);
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs + 2,
            children: [
              _PagerButton(
                label: 'Prev',
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous page',
                onTap: page > 1 ? () => onPage(page - 1) : null,
              ),
              for (final entry in window)
                if (entry == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    child: Text('…', style: AppTypography.numeric),
                  )
                else
                  _PageNumber(
                    page: entry,
                    selected: entry == page,
                    onTap: () => onPage(entry),
                  ),
              _PagerButton(
                label: 'Next',
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next page',
                iconAfter: true,
                onTap: page < pageCount ? () => onPage(page + 1) : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Phone pager: large Prev / Next buttons with "Page X of Y" between them,
/// which opens [showPageJumpSheet].
class MobilePaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  const MobilePaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _PagerButton(
        label: 'Prev',
        icon: Icons.chevron_left_rounded,
        tooltip: 'Previous page',
        minSize: AppSizes.tapTarget,
        onTap: page > 1 ? () => onPage(page - 1) : null,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Semantics(
          button: true,
          label: 'Page $page of $pageCount, jump to page',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => showPageJumpSheet(
              context,
              page: page,
              pageCount: pageCount,
              onPage: onPage,
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Page $page of $pageCount',
                        style: AppTypography.numeric.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.expand_less_rounded,
                        size: AppSizes.pagerIcon,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _PagerButton(
        label: 'Next',
        icon: Icons.chevron_right_rounded,
        tooltip: 'Next page',
        iconAfter: true,
        minSize: AppSizes.tapTarget,
        onTap: page < pageCount ? () => onPage(page + 1) : null,
      ),
    ],
  );
}

/// Bottom sheet with every page number; picking one calls [onPage].
Future<void> showPageJumpSheet(
  BuildContext context, {
  required int page,
  required int pageCount,
  required ValueChanged<int> onPage,
}) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.container,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(sheetContext).height * AppSizes.sheetHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Text('JUMP TO PAGE', style: AppTypography.label),
              ),
              Flexible(
                child: _PageJumpGrid(
                  page: page,
                  pageCount: pageCount,
                  onPick: (picked) => Navigator.of(sheetContext).pop(picked),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked != null && picked != page) onPage(picked);
}

/// Page numbers in rows of [AppSizes.pageJumpColumns], opened scrolled to
/// the current page.
class _PageJumpGrid extends StatefulWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPick;

  const _PageJumpGrid({
    required this.page,
    required this.pageCount,
    required this.onPick,
  });

  @override
  State<_PageJumpGrid> createState() => _PageJumpGridState();
}

class _PageJumpGridState extends State<_PageJumpGrid> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const columns = AppSizes.pageJumpColumns;
      const gap = AppSpacing.sm;
      final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final row = (widget.page - 1) ~/ columns;
      final scroll = _scroll ??= ScrollController(
        initialScrollOffset: row * (cell + gap),
      );
      return GridView.builder(
        controller: scroll,
        shrinkWrap: true,
        itemCount: widget.pageCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
        ),
        itemBuilder: (context, i) => _PageNumber(
          page: i + 1,
          selected: i + 1 == widget.page,
          onTap: () => widget.onPick(i + 1),
        ),
      );
    },
  );
}

class _PageNumber extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;
  const _PageNumber({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Page $page',
    child: Material(
      color: selected ? AppColors.crimson : AppColors.container,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: BorderSide(
          color: selected ? AppColors.crimson : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.pagerButton,
            minHeight: AppSizes.pagerButton,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '$page',
                style: AppTypography.numeric.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PagerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final bool iconAfter;
  final double minSize;
  final VoidCallback? onTap;

  const _PagerButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconAfter = false,
    this.minSize = AppSizes.pagerButton,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.border : AppColors.textSecondary;
    final iconWidget = Icon(icon, size: AppSizes.pagerIcon, color: color);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: Material(
          color: AppColors.container,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minSize,
                minHeight: minSize,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!iconAfter) iconWidget,
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.label.copyWith(color: color),
                    ),
                    if (iconAfter) iconWidget,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
