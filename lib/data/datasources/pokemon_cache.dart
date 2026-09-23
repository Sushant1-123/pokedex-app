import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';

/// Persistent, disk-backed cache (Hive) with a 1-hour TTL, per the assignment's
/// explicit "no in-memory cache" instruction. Each entry stores the JSON payload
/// plus the timestamp it was written, so reads can check freshness themselves.
class PokemonCache {
  final DateTime Function() _now;
  late Box<String> _listBox;
  late Box<String> _detailBox;
  late Box<String> _indexBox;
  late Box<String> _savedBox;
  bool _initialized = false;

  /// [clock] is injectable so the TTL can be verified without waiting an hour.
  PokemonCache({DateTime Function() clock = DateTime.now}) : _now = clock;

  /// Opens the boxes. Hive itself must already be initialised
  /// (`Hive.initFlutter()` in the app, `Hive.init(path)` in tests).
  Future<void> init() async {
    if (_initialized) return;
    _listBox = await Hive.openBox<String>(AppConstants.pokemonListBoxName);
    _detailBox = await Hive.openBox<String>(AppConstants.pokemonDetailBoxName);
    _indexBox = await Hive.openBox<String>(AppConstants.pokemonIndexBoxName);
    _savedBox = await Hive.openBox<String>(AppConstants.savedRecordsBoxName);
    _initialized = true;
  }

  // ---- List page cache (key = "offset:limit") ----

  List<dynamic>? readListPage(String key) {
    return _readFresh(_listBox, key)?['items'] as List<dynamic>?;
  }

  Future<void> writeListPage(
      String key, List<Map<String, dynamic>> items) async {
    await _writeFresh(_listBox, key, {'items': items});
  }

  // ---- Detail cache (key = pokemon name or id) ----

  Map<String, dynamic>? readDetail(String key) {
    return _readFresh(_detailBox, key)?['data'] as Map<String, dynamic>?;
  }

  Future<void> writeDetail(String key, Map<String, dynamic> data) async {
    await _writeFresh(_detailBox, key, {'data': data});
  }

  // ---- Name index cache (key = "all" or "type:<name>") ----

  List<dynamic>? readIndex(String key) {
    return _readFresh(_indexBox, key)?['entries'] as List<dynamic>?;
  }

  Future<void> writeIndex(
      String key, List<Map<String, dynamic>> entries) async {
    await _writeFresh(_indexBox, key, {'entries': entries});
  }

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

  /// Returns the stored envelope, or null (and evicts it) once it is older
  /// than [AppConstants.cacheTtl].
  Map<String, dynamic>? _readFresh(Box<String> box, String key) {
    final raw = box.get(key);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt =
        DateTime.fromMillisecondsSinceEpoch(envelope['cachedAt'] as int);
    if (_now().difference(cachedAt) > AppConstants.cacheTtl) {
      box.delete(key);
      return null;
    }
    return envelope;
  }

  Future<void> _writeFresh(
      Box<String> box, String key, Map<String, dynamic> payload) async {
    final envelope = {
      'cachedAt': _now().millisecondsSinceEpoch,
      ...payload,
    };
    await box.put(key, jsonEncode(envelope));
  }
}
