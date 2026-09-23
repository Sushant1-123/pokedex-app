import 'package:flutter/material.dart';

/// Search field kept in sync with [query], so clearing the search from
/// elsewhere (e.g. the empty-results view) also clears the text.
class PokemonSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const PokemonSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'SEARCH SPECIMENS BY NAME OR ID',
        prefixIcon: Icon(Icons.radar_rounded),
      ),
    );
  }
}
