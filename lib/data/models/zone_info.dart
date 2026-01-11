class ZoneInfo {
  final String code;
  final String name;
  final double lat;
  final double lng;
  final double distanceM;
  final String crowdingLevel;
  final int crowdingRank;
  final String crowdingColor;
  final int crowdingUpdatedAt;
  final String crowdingMessage;

  const ZoneInfo({
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
    this.distanceM = 0.0,
    this.crowdingLevel = '',
    this.crowdingRank = 0,
    this.crowdingColor = '',
    this.crowdingUpdatedAt = 0,
    this.crowdingMessage = '',
  });

  factory ZoneInfo.fromJson(Map<String, dynamic> json) {
    // null-safe 처리를 위해 각 필드를 안전하게 변환
    String safeString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    return ZoneInfo(
      code: safeString(json['code']),
      name: safeString(json['name']),
      lat: ((json['lat'] as num?) ?? 0).toDouble(),
      lng: ((json['lng'] as num?) ?? 0).toDouble(),
      distanceM: ((json['distance_m'] as num?) ?? 0).toDouble(),
      crowdingLevel: safeString(json['crowding_level']),
      crowdingRank: (json['crowding_rank'] as int?) ?? 0,
      crowdingColor: safeString(json['crowding_color']),
      crowdingUpdatedAt: (json['crowding_updated_at'] as int?) ?? 0,
      crowdingMessage: safeString(json['crowding_message']),
    );
  }

  /// 혼잡도가 "붐빔" 또는 "약간 붐빔"인지 확인
  bool get isCongested {
    return crowdingLevel == '붐빔' || crowdingLevel == '약간 붐빔';
  }

  /// 혼잡도 상태를 반전시킨 새로운 ZoneInfo 생성 (디버깅용)
  ZoneInfo copyWithInvertedCongestion() {
    final isCurrentlyCongested = isCongested;
    final newLevel = isCurrentlyCongested ? '여유' : '붐빔';
    final newRank = isCurrentlyCongested ? 4 : 1;
    final newColor = isCurrentlyCongested ? 'green' : 'red';

    return ZoneInfo(
      code: code,
      name: name,
      lat: lat,
      lng: lng,
      distanceM: distanceM,
      crowdingLevel: newLevel,
      crowdingRank: newRank,
      crowdingColor: newColor,
      crowdingUpdatedAt: crowdingUpdatedAt,
      crowdingMessage: crowdingMessage,
    );
  }
}
