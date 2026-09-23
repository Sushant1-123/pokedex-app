import 'package:flutter/material.dart';

class PokemonSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const PokemonSearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'SEARCH SPECIMENS BY NAME OR ID',
        prefixIcon: Icon(Icons.radar_rounded),
      ),
    );
  }
}
