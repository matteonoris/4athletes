import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/workout_place.dart';
import 'package:flutter_mobile/widgets/workout_location_field.dart';
import 'package:flutter_mobile/widgets/workout_location_preview.dart';
import 'package:flutter_test/flutter_test.dart';

const bormio = WorkoutPlace(
    name: 'Bormio',
    address: 'Lombardia, Italia',
    latitude: 46.46,
    longitude: 10.37);
const livigno = WorkoutPlace(
    name: 'Livigno',
    address: 'Lombardia, Italia',
    latitude: 46.53,
    longitude: 10.13);

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Manual location entry must not open a connection');
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'manual location stays offline in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final network = _NoNetwork();
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      String? changed;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
            body: Padding(
          padding: const EdgeInsets.all(20),
          child: WorkoutLocationField(
            controller: controller,
            place: null,
            onPlaceChanged: (_) {},
            onChanged: (value) => changed = value,
          ),
        )),
      ));
      for (final text in ['Bo', 'Bormio palestra', '']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(seconds: 3));
        expect(controller.text, text);
        expect(changed, text);
        expect(network.attempts, 0);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Inserisci il luogo a mano'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'editing a saved place clears coordinates in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      final controller = TextEditingController(text: bormio.label);
      addTearDown(controller.dispose);
      WorkoutPlace? selected = bormio;
      var changes = 0;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                  body: WorkoutLocationField(
                    controller: controller,
                    place: selected,
                    onPlaceChanged: (place) => setState(() {
                      selected = place;
                      changes++;
                    }),
                  ),
                )),
      ));
      await tester.pumpAndSettle();
      expect(controller.text, bormio.label);
      expect(selected, bormio);
      expect(changes, 0);
      await tester.enterText(find.byType(TextField), 'Palestra comunale');
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(controller.text, 'Palestra comunale');
      expect(find.text('Inserisci il luogo a mano'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('map failure offers retry and updates marker when place changes',
      (tester) async {
    Widget preview(WorkoutPlace place) => MaterialApp(
            home: Scaffold(
                body: WorkoutLocationPreview(
          place: place,
          tileProvider: _TestTiles(),
        )));
    await tester.pumpWidget(preview(bormio));
    await tester.pumpAndSettle();
    await tester.pumpWidget(preview(livigno));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point
            .latitude,
        livigno.latitude);
    final tile = TileImage(
      vsync: tester,
      coordinates: const TileCoordinates(0, 0, 0),
      imageProvider: MemoryImage(TileProvider.transparentImage),
      onLoadComplete: (_) {},
      onLoadError: (_, __, ___) {},
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );
    tester.widget<TileLayer>(find.byType(TileLayer)).errorTileCallback!(
        tile, Exception('offline'), null);
    tile.dispose();
    await tester.pump();
    await tester.pump();
    expect(find.text('Anteprima mappa non disponibile'), findsOneWidget);
    expect(find.text('Apri mappa'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
