import '../../../core/network/api_result.dart';
import '../../../core/utils/logger.dart';
import '../models/insight_request.dart';
import '../models/insight_response.dart';
import '../sources/remote/insight_api.dart';

class InsightRepository {
  InsightRepository({InsightApi? api}) : _api = api ?? InsightApi();

  final InsightApi _api;

  Future<ApiResult<PlacesInsightResponse>> getInsight(PlacesInsightRequest request) async {
    final result = await _api.getInsight(request);
    if (result is ApiSuccess<PlacesInsightResponse>) {
      logInfo('Insight success: ${result.data.alternatives.length} alternatives');
    }
    return result;
  }
}
