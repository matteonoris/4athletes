import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_place.dart';
import '../services/place_search_service.dart';

class WorkoutLocationField extends StatefulWidget {
  final TextEditingController controller;
  final WorkoutPlace? place;
  final ValueChanged<WorkoutPlace?> onPlaceChanged;
  final ValueChanged<String>? onChanged;
  final Future<List<WorkoutPlace>> Function(String)? search;

  const WorkoutLocationField({
    super.key,
    required this.controller,
    required this.place,
    required this.onPlaceChanged,
    this.onChanged,
    this.search,
  });

  @override
  State<WorkoutLocationField> createState() => _WorkoutLocationFieldState();
}

class _WorkoutLocationFieldState extends State<WorkoutLocationField> {
  final _focus = FocusNode();
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  String? _message;
  List<WorkoutPlace> _results = const [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _cancelSearch();
  }

  void _cancelSearch() {
    _debounce?.cancel();
    _revision++;
    setState(() {
      _results = const [];
      _loading = false;
      _message = null;
    });
  }

  void _changed(String value) {
    _cancelSearch();
    // A manually edited label must never keep the old marker.
    widget.onPlaceChanged(null);
    widget.onChanged?.call(value);
    if (value.trim().length < PlaceSearchService.minimumQueryLength) return;
    final revision = _revision;
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted || !_focus.hasFocus) return;
      setState(() => _loading = true);
      try {
        final results =
            await (widget.search ?? PlaceSearchService.shared.search)(value);
        if (!mounted || revision != _revision) return;
        setState(() {
          _results = results;
          _loading = false;
          _message = results.isEmpty
              ? 'Nessun luogo trovato. Puoi mantenere il testo inserito.'
              : null;
        });
      } catch (_) {
        if (!mounted || revision != _revision) return;
        setState(() {
          _loading = false;
          _message = 'Ricerca non disponibile. Puoi inserire il luogo a mano.';
        });
      }
    });
  }

  void _select(WorkoutPlace place) {
    _cancelSearch();
    widget.controller.value = TextEditingValue(
      text: place.label,
      selection: TextSelection.collapsed(offset: place.label.length),
    );
    widget.onPlaceChanged(place);
    widget.onChanged?.call(place.label);
    _focus.unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFieldTapRegion(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.words,
          onChanged: _changed,
          decoration: InputDecoration(
            labelText: 'Luogo',
            hintText: 'Cerca una località o un impianto',
            helperText: widget.place == null
                ? 'Scrivi almeno 3 lettere o inserisci il luogo a mano'
                : 'Luogo selezionato · anteprima nel riepilogo',
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : widget.place != null
                    ? Icon(Icons.check_circle_outline, color: colors.primary)
                    : null,
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final place in _results)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(place.name),
                    subtitle:
                        place.address.isEmpty ? null : Text(place.address),
                    onTap: () => _select(place),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright')),
                    child: const Text('© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!,
                style: TextStyle(color: colors.onSurfaceVariant)),
          ),
      ],
    ));
  }
}
