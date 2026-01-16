import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../../models/recommendations_response.dart';

class RecommendationsApi {
  RecommendationsApi({HttpClient? client}) : _client = client ?? _createClient();

  final HttpClient _client;

  static HttpClient _createClient() {
    final baseUrl = dotenv.env[Env.apiBaseUrl];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception(
        'API_BASE_URL이 .env 파일에 설정되지 않았습니다. '
        '실기기에서는 localhost 대신 실제 서버 IP나 도메인을 사용해야 합니다.',
      );
    }
    return HttpClient(baseUrl: baseUrl);
  }

  Future<ApiResult<RecommendationsResponse>> getRecommendations({
    required double lat,
    required double lng,
    required String category, // 'cafe' or 'restaurant'
    int? radiusKm,
    int? maxResults,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'category': category,
    };
    
    if (radiusKm != null) {
      // 킬로미터를 미터로 변환
      queryParams['radius_m'] = (radiusKm * 1000).toString();
    }
    
    if (maxResults != null) {
      queryParams['max_results'] = maxResults.toString();
    }

    final result = await _client.get(
      '/recommendations',
      query: queryParams,
    );
    switch (result) {
      case ApiSuccess<Map<String, dynamic>>(data: final data):
        return ApiSuccess(RecommendationsResponse.fromJson(data));
      case ApiFailure<Map<String, dynamic>>(message: final message):
        return ApiFailure(message);
      default:
        return const ApiFailure('Unknown error');
    }
  }
}
