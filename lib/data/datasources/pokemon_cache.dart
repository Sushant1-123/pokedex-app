import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';

/// The Hive boxes holding API responses, all with the 1h TTL.
enum CacheBox {
  /// Full records from /pokemon/{id}, key = id.
  detail(AppConstants.pokemonDetailBoxName),

  /// Name index ("all") and /type/{name} data ("typedata:<name>").
  nameIndex(AppConstants.pokemonIndexBoxName),

  /// /pokemon-species/{id}, key = species id.
  species(AppConstants.pokemonSpeciesBoxName),

  /// /evolution-chain/{id}, key = chain id.
  evolutionChain(AppConstants.evolutionChainBoxName),

  /// Habitat names ("all") and /pokemon-habitat/{name} ("habitat:<name>").
  habitat(AppConstants.habitatBoxName),

  /// Ability index ("all") and /ability/{name} ("ability:<name>").
  ability(AppConstants.abilityBoxName);

  const CacheBox(this.boxName);
  final String boxName;
}

/// Persistent, disk-backed cache (Hive) with a 1-hour TTL, per the assignment's
/// explicit "no in-memory cache" instruction. Each entry stores the JSON payload
/// plus the timestamp it was written, so reads can check freshness themselves.
class PokemonCache {
  final DateTime Function() _now;
  final Map<CacheBox, Box<String>> _boxes = {};
  late Box<String> _savedBox;
  bool _initialized = false;

  /// [clock] is injectable so the TTL can be verified without waiting an hour.
  PokemonCache({DateTime Function() clock = DateTime.now}) : _now = clock;

  /// Opens the boxes. Hive itself must already be initialised
  /// (`Hive.initFlutter()` in the app, `Hive.init(path)` in tests).
  Future<void> init() async {
    if (_initialized) return;
    for (final box in CacheBox.values) {
      _boxes[box] = await Hive.openBox<String>(box.boxName);
    }
    _savedBox = await Hive.openBox<String>(AppConstants.savedRecordsBoxName);
    _initialized = true;
  }

  /// Returns the cached payload, or null (and evicts it) once it is older
  /// than [AppConstants.cacheTtl].
  Object? read(CacheBox cacheBox, String key) {
    final box = _boxes[cacheBox]!;
    final raw = box.get(key);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      envelope['cachedAt'] as int,
    );
    if (_now().difference(cachedAt) > AppConstants.cacheTtl) {
      box.delete(key);
      return null;
    }
    return envelope['data'];
  }

  Future<void> write(CacheBox cacheBox, String key, Object data) async {
    final envelope = {'cachedAt': _now().millisecondsSinceEpoch, 'data': data};
    await _boxes[cacheBox]!.put(key, jsonEncode(envelope));
  }

  /// Number of cached API responses across all boxes (expired entries are
  /// only evicted when read, so this is an upper bound).
  int get entryCount =>
      _boxes.values.fold(0, (total, box) => total + box.length);

  List<Map<String, dynamic>> readSavedRecords() {
    return _savedBox.values
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList();
  }

  Future<void> writeSavedRecord(Map<String, dynamic> data) async {
    await _savedBox.put(data['id'].toString(), jsonEncode(data));
  }

  Future<void> deleteSavedRecord(int id) async {
    await _savedBox.delete(id.toString());
  }
}
