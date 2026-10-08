import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/workout_place.dart';

class PlaceSearchService {
  static final shared = PlaceSearchService();
  static const minimumQueryLength = 3;
  static const defaultEndpoint = String.fromEnvironment(
    'PHOTON_API_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );

  final http.Client _client;
  final Uri _endpoint;
  final _cache = <String, List<WorkoutPlace>>{};
  final _pending = <String, Future<List<WorkoutPlace>>>{};
  DateTime? _retryAfter;

  PlaceSearchService({http.Client? client, Uri? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse(defaultEndpoint);

  Future<List<WorkoutPlace>> search(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < minimumQueryLength) return const [];
    final key = normalized.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_pending.containsKey(key)) return _pending[key]!;
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      throw const PlaceSearchUnavailable();
    }
    final request = _fetch(normalized);
    _pending[key] = request;
    try {
      final places = await request;
      if (_cache.length >= 60) _cache.remove(_cache.keys.first);
      _cache[key] = places;
      return places;
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<WorkoutPlace>> _fetch(String query) async {
    final response = await _client.get(
      _endpoint.replace(queryParameters: {
        ..._endpoint.queryParameters,
        'q': query,
        'limit': '6',
        // Italian is not supported by every public Photon installation.
        // Accept-Language lets the server choose its supported fallback.
      }),
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'it,en;q=0.8',
        if (!kIsWeb) 'User-Agent': '4Athletes/1.0 (place search)',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode == 429 || response.statusCode == 503) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      _retryAfter = DateTime.now().add(Duration(seconds: seconds ?? 60));
    }
    if (response.statusCode != 200) throw const PlaceSearchUnavailable();
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map || payload['features'] is! List) {
      throw const PlaceSearchUnavailable();
    }
    final places = <WorkoutPlace>[];
    final seen = <String>{};
    for (final feature in payload['features'] as List) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties is! Map ||
          geometry is! Map ||
          geometry['type'] != 'Point') {
        continue;
      }
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final name =
          (properties['name'] ?? properties['street'] ?? properties['city'])
                  ?.toString()
                  .trim() ??
              '';
      final address = <String>{
        [properties['street'], properties['housenumber']]
            .where((part) => part != null)
            .join(' ')
            .trim(),
        for (final key in ['city', 'state', 'country'])
          properties[key]?.toString().trim() ?? '',
      }..removeWhere((part) => part.isEmpty || part == name);
      final place = WorkoutPlace.tryParse({
        'name': name,
        'address': address.join(', '),
        'latitude': coordinates[1],
        'longitude': coordinates[0],
        if (properties['osm_id'] != null)
          'osmId': '${properties['osm_type'] ?? ''}${properties['osm_id']}',
      });
      if (place != null &&
          seen.add('${place.label}:${place.latitude}:${place.longitude}')) {
        places.add(place);
      }
    }
    // Prefer names beginning with what was typed, retaining Photon relevance
    // for address searches and alternate spellings.
    final prefix = query.toLowerCase();
    return List.unmodifiable([
      ...places.where((place) => place.name.toLowerCase().startsWith(prefix)),
      ...places.where((place) => !place.name.toLowerCase().startsWith(prefix)),
    ].take(6));
  }

  void dispose() => _client.close();
}

class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable();
}
