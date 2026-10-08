/// A user-selected place. Kept inside existing workout JSON payloads.
class WorkoutPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? osmId;

  const WorkoutPlace({
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.osmId,
  });

  String get label => address.isEmpty ? name : '$name, $address';

  static WorkoutPlace? tryParse(dynamic value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim() ?? '';
    final lat = double.tryParse('${value['latitude']}');
    final lon = double.tryParse('${value['longitude']}');
    if (name.isEmpty ||
        lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    return WorkoutPlace(
      name: name,
      address: value['address']?.toString() ?? '',
      latitude: lat,
      longitude: lon,
      osmId: value['osmId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (osmId != null) 'osmId': osmId,
      };
}
