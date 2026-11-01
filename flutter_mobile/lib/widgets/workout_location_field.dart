import 'package:flutter/material.dart';

import '../models/workout_place.dart';

/// Manual entry only: typing a location must not contact a geocoding provider.
class WorkoutLocationField extends StatelessWidget {
  final TextEditingController controller;
  final WorkoutPlace? place;
  final ValueChanged<WorkoutPlace?> onPlaceChanged;
  final ValueChanged<String>? onChanged;

  const WorkoutLocationField({
    super.key,
    required this.controller,
    required this.place,
    required this.onPlaceChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      onChanged: (value) {
        // Preserve existing places until edited, then discard stale coordinates.
        onPlaceChanged(null);
        onChanged?.call(value);
      },
      decoration: InputDecoration(
        labelText: 'Luogo',
        hintText: 'Inserisci una località o un impianto',
        helperText: place == null
            ? 'Inserisci il luogo a mano'
            : 'Modificando il luogo rimuovi le coordinate salvate',
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.place_outlined),
      ),
    );
  }
}
