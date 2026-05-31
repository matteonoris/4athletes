import 'package:health/health.dart';

void main() {
  for (var type in HealthDataType.values) {
    if (type.name.contains('SLEEP')) {
      print(type.name);
    }
  }
}
