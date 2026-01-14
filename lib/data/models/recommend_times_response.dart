class RecommendTimesResponse {
  final String placeId;
  final String tz;
  final int days;
  final int minSamples;
  final int perDay;
  final int windowH;
  final bool includeLowSamples;
  final bool fallbackToHourly;
  final int totalSamples;
  final List<DayRecommendation> recommendations;

  const RecommendTimesResponse({
    required this.placeId,
    required this.tz,
    required this.days,
    required this.minSamples,
    required this.perDay,
    required this.windowH,
    required this.includeLowSamples,
    required this.fallbackToHourly,
    required this.totalSamples,
    required this.recommendations,
  });

  factory RecommendTimesResponse.fromJson(Map<String, dynamic> json) {
    final recommendationsList = (json['recommendations'] as List<dynamic>? ?? [])
        .map((e) => DayRecommendation.fromJson(
              e as Map<String, dynamic>? ?? <String, dynamic>{},
            ))
        .toList();

    return RecommendTimesResponse(
      placeId: json['place_id'] as String? ?? '',
      tz: json['tz'] as String? ?? 'Asia/Seoul',
      days: json['days'] as int? ?? 7,
      minSamples: json['min_samples'] as int? ?? 3,
      perDay: json['per_day'] as int? ?? 3,
      windowH: json['window_h'] as int? ?? 2,
      includeLowSamples: json['include_low_samples'] as bool? ?? false,
      fallbackToHourly: json['fallback_to_hourly'] as bool? ?? false,
      totalSamples: json['total_samples'] as int? ?? 0,
      recommendations: recommendationsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'tz': tz,
      'days': days,
      'min_samples': minSamples,
      'per_day': perDay,
      'window_h': windowH,
      'include_low_samples': includeLowSamples,
      'fallback_to_hourly': fallbackToHourly,
      'total_samples': totalSamples,
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
    };
  }
}

class DayRecommendation {
  final int dow;
  final String dowName;
  final List<TimeWindow> windows;
  final String? note;

  const DayRecommendation({
    required this.dow,
    required this.dowName,
    required this.windows,
    this.note,
  });

  factory DayRecommendation.fromJson(Map<String, dynamic> json) {
    final windowsList = (json['windows'] as List<dynamic>? ?? [])
        .map((e) => TimeWindow.fromJson(
              e as Map<String, dynamic>? ?? <String, dynamic>{},
            ))
        .toList();

    return DayRecommendation(
      dow: json['dow'] as int? ?? 0,
      dowName: json['dow_name'] as String? ?? '',
      windows: windowsList,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dow': dow,
      'dow_name': dowName,
      'windows': windows.map((e) => e.toJson()).toList(),
      if (note != null) 'note': note,
    };
  }
}

class TimeWindow {
  final int dow;
  final String dowName;
  final int startHour;
  final int endHour;
  final String label;
  final double avgRank;
  final int n;
  final List<int> hours;
  final String modeLevel;
  final bool fallback;
  final String? confidence;
  final String? reason;

  const TimeWindow({
    required this.dow,
    required this.dowName,
    required this.startHour,
    required this.endHour,
    required this.label,
    required this.avgRank,
    required this.n,
    required this.hours,
    required this.modeLevel,
    required this.fallback,
    this.confidence,
    this.reason,
  });

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    final hoursList = (json['hours'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toList();

    return TimeWindow(
      dow: json['dow'] as int? ?? 0,
      dowName: json['dow_name'] as String? ?? '',
      startHour: json['start_hour'] as int? ?? 0,
      endHour: json['end_hour'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      avgRank: (json['avg_rank'] as num?)?.toDouble() ?? 0.0,
      n: json['n'] as int? ?? 0,
      hours: hoursList,
      modeLevel: json['mode_level'] as String? ?? '',
      fallback: json['fallback'] as bool? ?? false,
      confidence: json['confidence'] as String?,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dow': dow,
      'dow_name': dowName,
      'start_hour': startHour,
      'end_hour': endHour,
      'label': label,
      'avg_rank': avgRank,
      'n': n,
      'hours': hours,
      'mode_level': modeLevel,
      'fallback': fallback,
      if (confidence != null) 'confidence': confidence,
      if (reason != null) 'reason': reason,
    };
  }
}
