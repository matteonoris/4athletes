import 'package:health/health.dart';

void main() {
  print("Enum values:");
  for (var val in HealthWorkoutActivityType.values) {
    print(val.name);
  }
}
