class SearchRequest {
  final String query;
  final double lat;
  final double lng;
  final int size;
  final int radiusM;
  final String scope; // "cache" | "api" | "all"
  final String categoryScope; // "cafe" | "food" | "food_cafe" | "all"

  const SearchRequest({
    required this.query,
    required this.lat,
    required this.lng,
    this.size = 5,
    this.radiusM = 3000,
    this.scope = 'all', // 기본값: "all" (cache + api)
    this.categoryScope = 'food_cafe', // 기본값: "food_cafe"
  });

  Map<String, String> toQuery() => {
        'query': query,
        'lat': lat.toString(),
        'lng': lng.toString(),
        'size': size.toString(),
        'radius_m': radiusM.toString(),
        'scope': scope,
        'category_scope': categoryScope,
      };
}




