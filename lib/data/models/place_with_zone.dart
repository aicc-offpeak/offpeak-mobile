import 'place.dart';
import 'zone_info.dart';

class PlaceWithZone {
  final Place place;
  final ZoneInfo zone;

  const PlaceWithZone({
    required this.place,
    required this.zone,
  });

  factory PlaceWithZone.fromJson(Map<String, dynamic> json) {
    return PlaceWithZone(
      place: Place.fromJson(
        json['place'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      zone: ZoneInfo.fromJson(
        json['zone'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}
