import 'place.dart';

class PlacesInsightRequest {
  final Place selected;
  final double? userLat;
  final double? userLng;
  final String recommendFrom;
  final int radiusM;
  final int maxCandidates;
  final int maxAlternatives;
  final String? category;
  final bool includeImage;

  const PlacesInsightRequest({
    required this.selected,
    this.userLat,
    this.userLng,
    this.recommendFrom = 'selected',
    this.radiusM = 1200,
    this.maxCandidates = 25,
    this.maxAlternatives = 3,
    this.category,
    this.includeImage = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'selected': selected.toJson(),
      if (userLat != null) 'user_lat': userLat,
      if (userLng != null) 'user_lng': userLng,
      'recommend_from': recommendFrom,
      'radius_m': radiusM,
      'max_candidates': maxCandidates,
      'max_alternatives': maxAlternatives,
      if (category != null) 'category': category,
      'include_image': includeImage,
    };
  }
}
