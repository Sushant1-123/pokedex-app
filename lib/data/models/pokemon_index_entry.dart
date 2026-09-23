/// One row of the lightweight name index: just enough to search the whole
/// catalog by name and to resolve a match to its full record later.
class PokemonIndexEntry {
  final int id;
  final String name;

  const PokemonIndexEntry({required this.id, required this.name});

  /// Parses a PokeAPI named resource (`{name, url}`), taking the id from the
  /// trailing path segment of `url`, e.g. `.../pokemon/25/` -> 25.
  factory PokemonIndexEntry.fromResourceJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    final segments = Uri.parse(url).pathSegments.where((s) => s.isNotEmpty);
    return PokemonIndexEntry(
      id: int.parse(segments.last),
      name: json['name'] as String,
    );
  }

  factory PokemonIndexEntry.fromCacheJson(Map<String, dynamic> json) =>
      PokemonIndexEntry(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toCacheJson() => {'id': id, 'name': name};
}
