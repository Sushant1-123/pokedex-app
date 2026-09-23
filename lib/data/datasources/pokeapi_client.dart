import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/ability.dart';
import '../models/evolution_chain.dart';
import '../models/habitat.dart';
import '../models/pokemon_detail.dart';
import '../models/pokemon_index_entry.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type_data.dart';

/// The ONLY place in the app that talks to the network, and it only ever
/// talks to pokeapi.co, per the assignment's "sole data source" instruction.
class PokeApiClient {
  final http.Client _http;
  PokeApiClient({http.Client? client}) : _http = client ?? http.Client();

  /// Fetches the name + id of every Pokemon in one lightweight request, so
  /// search and paging can cover the whole catalog without loading every
  /// record.
  Future<List<PokemonIndexEntry>> fetchPokemonIndex() async {
    final body = await _getJson(
      'pokemon?limit=${AppConstants.nameIndexLimit}&offset=0',
      'Pokemon index',
    );
    return (body['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PokemonIndexEntry.fromResourceJson)
        .toList();
  }

  /// GET /type/{name}: the type's members and its damage relations.
  Future<PokemonTypeData> fetchTypeData(String type) async =>
      PokemonTypeData.fromJson(await _getJson('type/$type', 'type $type'));

  Future<PokemonDetail> fetchPokemonDetail(int id) async =>
      PokemonDetail.fromJson(await _getJson('pokemon/$id', 'Pokemon #$id'));

  Future<PokemonSpecies> fetchSpecies(int speciesId) async =>
      PokemonSpecies.fromJson(
        await _getJson('pokemon-species/$speciesId', 'species #$speciesId'),
      );

  Future<EvolutionChain> fetchEvolutionChain(int chainId) async =>
      EvolutionChain.fromJson(
        await _getJson('evolution-chain/$chainId', 'evolution chain #$chainId'),
      );

  /// Names of every habitat (GET /pokemon-habitat).
  Future<List<String>> fetchHabitatNames() async {
    final body = await _getJson('pokemon-habitat?limit=100', 'habitats');
    return [
      for (final r in body['results'] as List<dynamic>)
        (r as Map<String, dynamic>)['name'] as String,
    ];
  }

  Future<PokemonHabitat> fetchHabitat(String name) async =>
      PokemonHabitat.fromJson(
        await _getJson('pokemon-habitat/$name', 'habitat $name'),
      );

  /// Every ability (GET /ability?limit=100000).
  Future<List<AbilityEntry>> fetchAbilityIndex() async {
    final body = await _getJson(
      'ability?limit=${AppConstants.nameIndexLimit}',
      'abilities',
    );
    return [
      for (final r in body['results'] as List<dynamic>)
        abilityEntryFromJson(r as Map<String, dynamic>),
    ];
  }

  Future<AbilityDetail> fetchAbility(String name) async =>
      AbilityDetail.fromJson(await _getJson('ability/$name', 'ability $name'));

  Future<Map<String, dynamic>> _getJson(String path, String what) async {
    final res = await _http.get(
      Uri.parse('${AppConstants.pokeApiBaseUrl}/$path'),
    );
    if (res.statusCode != 200) {
      throw PokeApiException('Failed to load $what (${res.statusCode})');
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
