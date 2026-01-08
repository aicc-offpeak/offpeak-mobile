class SearchRequest {
  final String keyword;
  final double? latitude;
  final double? longitude;

  const SearchRequest({required this.keyword, this.latitude, this.longitude});

  Map<String, String> toQuery() => {
        'q': keyword,
        if (latitude != null) 'lat': latitude.toString(),
        if (longitude != null) 'lng': longitude.toString(),
      };
}




