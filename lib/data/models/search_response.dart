import 'place.dart';

class SearchResponse {
  final List<Place> places;
  final int totalCount;

  const SearchResponse({required this.places, required this.totalCount});

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => Place.fromJson(
              e as Map<String, dynamic>? ?? <String, dynamic>{},
            ))
        .toList();
    return SearchResponse(
      places: items,
      totalCount: (json['total_count'] as int?) ?? items.length,
    );
  }
}




