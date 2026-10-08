import 'dart:async';

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

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'selection, editing and readable preview in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      WorkoutPlace? selected;
      var requests = 0;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                  body: ListView(padding: const EdgeInsets.all(20), children: [
                    WorkoutLocationField(
                        controller: controller,
                        place: selected,
                        onPlaceChanged: (place) =>
                            setState(() => selected = place),
                        search: (query) async {
                          requests++;
                          return [bormio];
                        }),
                    if (selected != null)
                      WorkoutLocationPreview(
                          place: selected!, tileProvider: _TestTiles()),
                  ]),
                )),
      ));
      await tester.enterText(find.byType(TextField), 'Bo');
      await tester.pump(const Duration(seconds: 2));
      expect(requests, 0);
      await tester.enterText(find.byType(TextField), 'Borm');
      await tester.pump(const Duration(milliseconds: 999));
      expect(requests, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(requests, 1);
      await tester.tap(find.text('Bormio'));
      await tester.pumpAndSettle();
      expect(controller.text, bormio.label);
      expect(selected, bormio);
      expect(find.byType(FlutterMap), findsOneWidget);
      final marker =
          tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
      expect(marker.point.latitude, bormio.latitude);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Apri mappa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Luogo manuale');
      await tester.pump();
      expect(selected, isNull);
      expect(find.byType(FlutterMap), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('discards stale results and remains usable after a network error',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final first = Completer<List<WorkoutPlace>>();
    final second = Completer<List<WorkoutPlace>>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WorkoutLocationField(
      controller: controller,
      place: null,
      onPlaceChanged: (_) {},
      search: (query) => query == 'Borm' ? first.future : second.future,
    ))));
    await tester.enterText(find.byType(TextField), 'Borm');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Livi');
    await tester.pump(const Duration(seconds: 1));
    second.complete([livigno]);
    await tester.pump();
    first.complete([bormio]);
    await tester.pump();
    expect(find.text('Livigno'), findsOneWidget);
    expect(find.text('Bormio'), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WorkoutLocationField(
      controller: controller,
      place: null,
      onPlaceChanged: (_) {},
      search: (_) async => throw Exception('offline'),
    ))));
    await tester.enterText(find.byType(TextField), 'Cortina');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Ricerca non disponibile. Puoi inserire il luogo a mano.'),
        findsOneWidget);
    expect(controller.text, 'Cortina');
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
