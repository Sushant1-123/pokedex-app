import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/design_tokens.dart';

/// Glowing type pill from the Stitch cards, in the type's canonical colour.
class TypePill extends StatelessWidget {
  final String type;
  final bool large;
  const TypePill({super.key, required this.type, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.md : AppSpacing.sm,
        vertical: large ? AppSpacing.xs + 2 : AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        border: Border.all(color: color.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .28), blurRadius: 10),
        ],
      ),
      child: Text(
        type.toUpperCase(),
        style: (large ? AppTypography.label : AppTypography.caption).copyWith(
          color: color,
        ),
      ),
    );
  }
}

/// The "bonus criterion" animated type badge: a [TypePill] that scales,
/// fades and slides in on mount, staggered by [index].
class TypeBadge extends StatefulWidget {
  final String type;
  final int index;
  const TypeBadge({super.key, required this.type, this.index = 0});

  @override
  State<TypeBadge> createState() => _TypeBadgeState();
}

class _TypeBadgeState extends State<TypeBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: TypePill(type: widget.type, large: true),
      ),
    ),
  );
}
