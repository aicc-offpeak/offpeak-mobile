import '../../../core/network/api_result.dart';
import '../../../core/utils/logger.dart';
import '../models/recommend_times_response.dart';
import '../sources/remote/recommend_times_api.dart';

class RecommendTimesRepository {
  RecommendTimesRepository({RecommendTimesApi? api}) : _api = api ?? RecommendTimesApi();

  final RecommendTimesApi _api;

  Future<ApiResult<RecommendTimesResponse>> getRecommendTimes(String placeId) async {
    final result = await _api.getRecommendTimes(placeId);
    if (result is ApiSuccess<RecommendTimesResponse>) {
      logInfo('RecommendTimes success: ${result.data.recommendations.length} days');
    }
    return result;
  }
}
