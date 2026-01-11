class Place {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final double distanceM;
  final String categoryGroupCode;
  final String imageUrl;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category = '',
    this.distanceM = 0.0,
    this.categoryGroupCode = '',
    this.imageUrl = '',
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // null-safe 처리를 위해 각 필드를 안전하게 변환
    String safeString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    return Place(
      id: safeString(json['id']),
      name: safeString(json['name']),
      address: safeString(json['address']) != '' 
          ? safeString(json['address'])
          : safeString(json['address_name']),
      latitude: ((json['lat'] ?? json['latitude'] ?? 0) as num).toDouble(),
      longitude: ((json['lng'] ?? json['longitude'] ?? 0) as num).toDouble(),
      category: safeString(json['category_name']) != ''
          ? safeString(json['category_name'])
          : safeString(json['category_group_name']),
      distanceM: ((json['distance_m'] ?? json['distance'] ?? 0) as num).toDouble(),
      categoryGroupCode: safeString(json['category_group_code']),
      imageUrl: safeString(json['image_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': latitude,
      'lng': longitude,
      'category_name': category,
      'distance_m': distanceM,
      'category_group_code': categoryGroupCode,
      'image_url': imageUrl,
    };
  }
}




