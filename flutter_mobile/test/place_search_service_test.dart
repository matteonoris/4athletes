import 'dart:convert';

import 'package:flutter_mobile/services/place_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> feature(String name, {double lat = 46.46}) => {
        'geometry': {
          'type': 'Point',
          'coordinates': [10.37, lat]
        },
        'properties': {
          'name': name,
          'state': 'Lombardia',
          'country': 'Italia',
          'osm_id': 123,
          'osm_type': 'R'
        },
      };

  test(
      'searches prefixes, parses coordinates, skips invalid results and caches',
      () async {
    var calls = 0;
    final service = PlaceSearchService(client: MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['q'], 'Borm');
      expect(request.url.queryParameters['limit'], '6');
      expect(request.headers['User-Agent'], contains('4Athletes'));
      return http.Response(
          jsonEncode({
            'features': [
              feature('Terme di Bormio'),
              feature('Bormio'),
              feature('Invalid', lat: 99),
              feature('Bormio'),
              {'geometry': null},
            ]
          }),
          200);
    }));
    addTearDown(service.dispose);
    expect(await service.search('Bo'), isEmpty);
    expect(calls, 0);
    final places = await service.search(' Borm ');
    expect(places.map((place) => place.name), ['Bormio', 'Terme di Bormio']);
    expect(places.first.latitude, 46.46);
    expect(places.first.longitude, 10.37);
    expect(places.first.label, 'Bormio, Lombardia, Italia');
    expect(await service.search('borm'), same(places));
    expect(calls, 1);
  });

  test('coalesces repeated requests while a search is in flight', () async {
    var calls = 0;
    final service = PlaceSearchService(client: MockClient((_) async {
      calls++;
      return http.Response('{"features":[]}', 200);
    }));
    addTearDown(service.dispose);
    await Future.wait([service.search('Bormio'), service.search('Bormio')]);
    expect(calls, 1);
  });

  test('backs off on rate limits and never caches failed searches', () async {
    var calls = 0;
    final service = PlaceSearchService(client: MockClient((_) async {
      calls++;
      return http.Response('', 429, headers: {'retry-after': '120'});
    }));
    addTearDown(service.dispose);
    await expectLater(
        service.search('Bormio'), throwsA(isA<PlaceSearchUnavailable>()));
    await expectLater(
        service.search('Livigno'), throwsA(isA<PlaceSearchUnavailable>()));
    expect(calls, 1);
  });

  test('reports malformed responses and allows a later retry', () async {
    var calls = 0;
    final service = PlaceSearchService(
        client: MockClient((_) async =>
            http.Response(calls++ == 0 ? '{}' : '{"features":[]}', 200)));
    addTearDown(service.dispose);
    await expectLater(
        service.search('Bormio'), throwsA(isA<PlaceSearchUnavailable>()));
    expect(await service.search('Bormio'), isEmpty);
    expect(calls, 2);
  });
}
