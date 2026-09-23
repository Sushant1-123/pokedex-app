import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Whether the platform uses Cmd rather than Ctrl for shortcuts. On the web
/// [defaultTargetPlatform] reflects the browser's OS.
bool get usesCommandKey =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Keyboard shortcuts only make sense on the web and desktop.
bool get supportsKeyboardShortcuts =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Search field kept in sync with [query] (so clearing the search elsewhere
/// clears the text), with a clear button and, when [showShortcutHint], the
/// Cmd K / Ctrl K hint.
class PokemonSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;
  final bool showShortcutHint;

  const PokemonSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    required this.focusNode,
    this.showShortcutHint = false,
  });

  @override
  State<PokemonSearchBar> createState() => _PokemonSearchBarState();
}

class _PokemonSearchBarState extends State<PokemonSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(PokemonSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        cursorColor: AppColors.cyan,
        decoration: InputDecoration(
          hintText: 'Search Pokémon by name or #0006',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(Icons.search_rounded, size: 22),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showShortcutHint) const _KeyHint(),
              if (value.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

/// ⌘K on Apple platforms, Ctrl K elsewhere. The ⌘ is an icon because the
/// bundled font has no such glyph.
class _KeyHint extends StatelessWidget {
  const _KeyHint();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: AppSpacing.xs),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: AppColors.containerHigh,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (usesCommandKey)
          const Icon(
            Icons.keyboard_command_key_rounded,
            size: 11,
            color: AppColors.textMuted,
          ),
        Text(usesCommandKey ? 'K' : 'Ctrl K', style: AppTypography.caption),
      ],
    ),
  );
}
