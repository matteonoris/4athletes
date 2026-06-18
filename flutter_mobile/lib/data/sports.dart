import 'package:flutter/material.dart';

class Sport {
  final String id;
  final String name;
  final IconData icon;

  const Sport(this.id, this.name, this.icon);
}

const List<Sport> sportsData = [
  Sport('weightlifting', 'Pesi / Palestra', Icons.fitness_center),
  Sport('alpine_skiing', 'Sci Alpino', Icons.snowboarding),
  Sport('trail_running', 'Trail Running', Icons.terrain),
  Sport('road_running', 'Corsa su Strada', Icons.directions_run),
  Sport('soccer', 'Calcio', Icons.sports_soccer),
  Sport('tennis', 'Tennis', Icons.sports_tennis),
  Sport('road_cycling', 'Ciclismo', Icons.directions_bike),
  Sport('spearfishing', 'Pesca Subacquea', Icons.scuba_diving),
  Sport('stretching', 'Mobilità / Yoga', Icons.self_improvement),
  Sport('athletic_prep', 'Prep. Atletica', Icons.run_circle),
  Sport('physiotherapy', 'Fisioterapia', Icons.medical_services),
  Sport('hyperarch', 'Hyperarch Fascia Training', Icons.fitness_center),
  Sport('lattacidemia', 'Lattacidemia', Icons.science),
  Sport('tendon_isometrics', 'Isometrie Tendini', Icons.accessibility_new),
];
