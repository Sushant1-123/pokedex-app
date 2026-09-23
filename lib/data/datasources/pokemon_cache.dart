import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';

/// Persistent, disk-backed cache (Hive) with a 1-hour TTL, per the assignment's
/// explicit "no in-memory cache" instruction. Each entry stores the JSON payload
/// plus the timestamp it was written, so reads can check freshness themselves.
class PokemonCache {
  late Box<String> _listBox;
  late Box<String> _detailBox;
  late Box<String> _savedBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _listBox = await Hive.openBox<String>(AppConstants.pokemonListBoxName);
    _detailBox = await Hive.openBox<String>(AppConstants.pokemonDetailBoxName);
    _savedBox = await Hive.openBox<String>(AppConstants.savedRecordsBoxName);
    _initialized = true;
  }

  // ---- List page cache (key = "offset:limit") ----

  List<dynamic>? readListPage(String key) {
    final raw = _listBox.get(key);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    if (_isExpired(envelope['cachedAt'] as int)) {
      _listBox.delete(key);
      return null;
    }
    return envelope['items'] as List<dynamic>;
  }

  Future<void> writeListPage(
      String key, List<Map<String, dynamic>> items) async {
    final envelope = {
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'items': items,
    };
    await _listBox.put(key, jsonEncode(envelope));
  }

  // ---- Detail cache (key = pokemon name or id) ----

  Map<String, dynamic>? readDetail(String key) {
    final raw = _detailBox.get(key);
    if (raw == null) return null;
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    if (_isExpired(envelope['cachedAt'] as int)) {
      _detailBox.delete(key);
      return null;
    }
    return envelope['data'] as Map<String, dynamic>;
  }

  Future<void> writeDetail(String key, Map<String, dynamic> data) async {
    final envelope = {
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await _detailBox.put(key, jsonEncode(envelope));
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

  bool _isExpired(int cachedAtMillis) {
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
    return DateTime.now().difference(cachedAt) > AppConstants.cacheTtl;
  }
}
