import 'place.dart';

class RecommendationsResponse {
  final List<Place> places;

  const RecommendationsResponse({
    required this.places,
  });

  factory RecommendationsResponse.fromJson(Map<String, dynamic> json) {
    // 백엔드는 {"items": [...]} 형식으로 반환
    // 각 item은 {"place": {...}, "zone": {...}} 구조
    final itemsList = (json['items'] as List<dynamic>? ?? []);
    final placesList = itemsList
        .map((item) {
          final itemMap = item as Map<String, dynamic>? ?? <String, dynamic>{};
          final placeMap = itemMap['place'] as Map<String, dynamic>? ?? <String, dynamic>{};
          final zoneMap = itemMap['zone'] as Map<String, dynamic>? ?? <String, dynamic>{};
          
          // zone의 혼잡도 정보를 place에 추가
          final placeJson = Map<String, dynamic>.from(placeMap);
          placeJson['crowding_level'] = zoneMap['crowding_level'] ?? '';
          
          return Place.fromJson(placeJson);
        })
        .toList();

    return RecommendationsResponse(
      places: placesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'places': places.map((e) => e.toJson()).toList(),
    };
  }
}
