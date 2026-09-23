import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Page buttons to show, like the Stitch pager "1 2 3 … 103": the first and
/// last page plus a window of three around [current]. `null` marks an
/// ellipsis; a gap of a single page shows that page instead.
List<int?> pageWindow(int current, int count) {
  if (count <= 1) return const [1];
  final start = (current - 1).clamp(1, (count - 2).clamp(1, count));
  final end = (start + 2).clamp(1, count);
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

/// Prev / numbered pages / Next.
class PaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  /// Icon-only Prev/Next for narrow screens.
  final bool compact;

  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs + 2,
      children: [
        _PagerButton(
          label: compact ? null : 'Prev',
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          onTap: page > 1 ? () => onPage(page - 1) : null,
        ),
        for (final entry in pageWindow(page, pageCount))
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
          label: compact ? null : 'Next',
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          iconAfter: true,
          onTap: page < pageCount ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
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
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
  final String? label;
  final IconData icon;
  final String tooltip;
  final bool iconAfter;
  final VoidCallback? onTap;

  const _PagerButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconAfter = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.border : AppColors.textSecondary;
    final iconWidget = Icon(icon, size: 18, color: color);
    return Tooltip(
      message: tooltip,
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
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!iconAfter) iconWidget,
                  if (label case final String label)
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
    );
  }
}
