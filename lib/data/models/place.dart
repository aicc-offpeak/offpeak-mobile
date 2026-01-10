class Place {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final double distanceM;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category = '',
    this.distanceM = 0.0,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? json['address_name'] ?? '',
      latitude: (json['lat'] ?? 0).toDouble(),
      longitude: (json['lng'] ?? 0).toDouble(),
      category: json['category_name'] ?? json['category_group_name'] ?? '',
      distanceM: (json['distance_m'] ?? json['distance'] ?? 0).toDouble(),
    );
  }
}




