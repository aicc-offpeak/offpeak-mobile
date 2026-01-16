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
  final String crowdingLevel; // 혼잡도 레벨 (여유, 보통, 약간 붐빔, 붐빔)
  final int crowdingUpdatedAt; // 혼잡도 갱신 시각 (epoch timestamp)

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
    this.crowdingLevel = '',
    this.crowdingUpdatedAt = 0,
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
      crowdingLevel: safeString(json['crowding_level'] ?? json['crowdingLevel']),
      crowdingUpdatedAt: ((json['crowding_updated_at'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address_name': address, // 백엔드는 address_name을 기대
      'lat': latitude,
      'lng': longitude,
      'category_name': category,
      'distance_m': distanceM,
      'category_group_code': categoryGroupCode,
      'image_url': imageUrl,
      // 백엔드가 기대하는 선택 필드들 (기본값)
      'category_group_name': '',
      'phone': '',
      'road_address_name': '',
      'place_url': '',
    };
  }
}




