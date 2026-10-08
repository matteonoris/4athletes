import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_place.dart';

class WorkoutLocationPreview extends StatefulWidget {
  final WorkoutPlace place;
  final TileProvider? tileProvider;

  const WorkoutLocationPreview(
      {super.key, required this.place, this.tileProvider});

  @override
  State<WorkoutLocationPreview> createState() => _WorkoutLocationPreviewState();
}

class _WorkoutLocationPreviewState extends State<WorkoutLocationPreview> {
  static const _tileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  bool _failed = false;
  int _attempt = 0;

  @override
  void didUpdateWidget(covariant WorkoutLocationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.latitude != widget.place.latitude ||
        oldWidget.place.longitude != widget.place.longitude) {
      _failed = false;
      _attempt++;
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the saved place visible even when no browser is available.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire la mappa. Riprova.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final colors = Theme.of(context).colorScheme;
    final point = LatLng(place.latitude, place.longitude);
    final attempt = _attempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Semantics(
          label: 'Mappa di ${place.label}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: _failed
                  ? ColoredBox(
                      color: colors.surfaceContainerHigh,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined),
                            const SizedBox(height: 8),
                            const Text('Anteprima mappa non disponibile'),
                            TextButton(
                              onPressed: () => setState(() {
                                _failed = false;
                                _attempt++;
                              }),
                              child: const Text('Riprova'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : FlutterMap(
                      key: ValueKey(
                          '${place.latitude}:${place.longitude}:$_attempt'),
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 13,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                        backgroundColor: colors.surfaceContainerHigh,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _tileUrl,
                          userAgentPackageName: 'com.matteonoris.app4athletes',
                          tileProvider: widget.tileProvider,
                          panBuffer: 0,
                          keepBuffer: 0,
                          maxNativeZoom: 19,
                          evictErrorTileStrategy:
                              EvictErrorTileStrategy.dispose,
                          errorTileCallback: (_, __, ___) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_failed && attempt == _attempt) {
                                setState(() => _failed = true);
                              }
                            });
                            WidgetsBinding.instance.ensureVisualUpdate();
                          },
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on,
                                size: 42,
                                color: Color(0xFFC52C32),
                                shadows: [
                                  Shadow(color: Colors.white, blurRadius: 3)
                                ]),
                          ),
                        ]),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Material(
                            color: colors.surface,
                            child: InkWell(
                              onTap: () => _open(Uri.parse(
                                  'https://www.openstreetmap.org/copyright')),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Text('© OpenStreetMap contributors',
                                    style: TextStyle(
                                        fontSize: 10, color: colors.onSurface)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _open(Uri.https('www.openstreetmap.org', '/', {
              'mlat': '${place.latitude}',
              'mlon': '${place.longitude}',
            }).replace(
                fragment: 'map=15/${place.latitude}/${place.longitude}')),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Apri mappa'),
          ),
        ),
      ],
    );
  }
}
