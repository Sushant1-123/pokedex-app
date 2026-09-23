import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/pokemon_summary.dart';
import '../models/pokemon_detail.dart';
import '../models/pokemon_index_entry.dart';

/// The ONLY place in the app that talks to the network, and it only ever
/// talks to pokeapi.co, per the assignment's "sole data source" instruction.
class PokeApiClient {
  final http.Client _http;
  PokeApiClient({http.Client? client}) : _http = client ?? http.Client();

  /// Fetches [limit] Pokemon starting at [offset] and resolves each one's
  /// full record (needed for types + artwork) via the detail endpoint.
  /// PokeAPI's /pokemon list endpoint doesn't include types or artwork,
  /// so we fetch details in parallel for the requested page.
  Future<List<PokemonSummary>> fetchPokemonPage({
    required int offset,
    required int limit,
  }) async {
    final listUri = Uri.parse(
      '${AppConstants.pokeApiBaseUrl}/pokemon?offset=$offset&limit=$limit',
    );
    final listRes = await _http.get(listUri);
    if (listRes.statusCode != 200) {
      throw PokeApiException(
          'Failed to load Pokemon list (${listRes.statusCode})');
    }
    final listBody = jsonDecode(listRes.body) as Map<String, dynamic>;
    final results =
        (listBody['results'] as List<dynamic>).cast<Map<String, dynamic>>();

    final details = await Future.wait(
      results.map((r) => _fetchDetailJson(r['url'] as String)),
    );

    return details.map(PokemonSummary.fromDetailJson).toList();
  }

  /// Fetches the name + id of every Pokemon in one lightweight request, so
  /// search can cover the whole catalog without loading every record.
  Future<List<PokemonIndexEntry>> fetchPokemonIndex() async {
    final uri = Uri.parse(
      '${AppConstants.pokeApiBaseUrl}/pokemon'
      '?limit=${AppConstants.nameIndexLimit}&offset=0',
    );
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      throw PokeApiException(
          'Failed to load Pokemon index (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PokemonIndexEntry.fromResourceJson)
        .toList();
  }

  Future<PokemonDetail> fetchPokemonDetail(String nameOrId) async {
    final uri = Uri.parse('${AppConstants.pokeApiBaseUrl}/pokemon/$nameOrId');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      throw PokeApiException('Failed to load $nameOrId (${res.statusCode})');
    }
    return PokemonDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _fetchDetailJson(String url) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw PokeApiException('Failed to load $url (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void dispose() => _http.close();
}

class PokeApiException implements Exception {
  final String message;
  PokeApiException(this.message);
  @override
  String toString() => message;
}
