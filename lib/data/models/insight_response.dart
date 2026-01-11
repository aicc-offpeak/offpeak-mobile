import 'place_with_zone.dart';

class PlacesInsightResponse {
  final PlaceWithZone selected;
  final List<PlaceWithZone> alternatives;

  const PlacesInsightResponse({
    required this.selected,
    this.alternatives = const [],
  });

  factory PlacesInsightResponse.fromJson(Map<String, dynamic> json) {
    final alternativesList = (json['alternatives'] as List<dynamic>? ?? [])
        .map((e) => PlaceWithZone.fromJson(
              e as Map<String, dynamic>? ?? <String, dynamic>{},
            ))
        .toList();

    return PlacesInsightResponse(
      selected: PlaceWithZone.fromJson(
        json['selected'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      alternatives: alternativesList,
    );
  }
}
