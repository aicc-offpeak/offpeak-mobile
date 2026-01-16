import '../../../core/network/api_result.dart';
import '../../../core/utils/logger.dart';
import '../models/recommendations_response.dart';
import '../sources/remote/recommendations_api.dart';

class RecommendationsRepository {
  RecommendationsRepository({RecommendationsApi? api})
      : _api = api ?? RecommendationsApi();

  final RecommendationsApi _api;

  /// 반경 단계별 자동 확대: 3km → 5km → 10km → 15km → 20km
  /// 각 단계에서 결과 있으면 즉시 반환
  Future<ApiResult<RecommendationsResponse>> getRecommendations({
    required double lat,
    required double lng,
    String category = 'cafe', // 기본값: 'cafe'
    Function(int radiusKm)? onRadiusChange,
  }) async {
    final radiusSteps = [3, 5, 10, 15, 20];
    
    for (final radiusKm in radiusSteps) {
      logInfo('Trying recommendations with radius: ${radiusKm}km, category: $category');
      onRadiusChange?.call(radiusKm);
      
      final result = await _api.getRecommendations(
        lat: lat,
        lng: lng,
        category: category,
        radiusKm: radiusKm,
        maxResults: 10, // 최대 10개
      );
      
      switch (result) {
        case ApiSuccess<RecommendationsResponse>(data: final data):
          if (data.places.isNotEmpty) {
            logInfo(
                'Recommendations success: ${data.places.length} places found at ${radiusKm}km');
            return result;
          }
          // 결과가 비어있으면 다음 반경으로 계속
          logInfo('No results at ${radiusKm}km, trying next radius...');
          break;
        case ApiFailure<RecommendationsResponse>():
          // API 에러가 발생하면 즉시 반환
          return result;
        default:
          break;
      }
    }
    
    // 모든 반경에서 결과가 없었음
    logInfo('No recommendations found in any radius (up to 20km)');
    return const ApiSuccess(RecommendationsResponse(places: []));
  }
}
