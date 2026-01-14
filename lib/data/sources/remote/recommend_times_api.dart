import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../../models/recommend_times_response.dart';

class RecommendTimesApi {
  RecommendTimesApi({HttpClient? client}) : _client = client ?? _createClient();

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

  Future<ApiResult<RecommendTimesResponse>> getRecommendTimes(String placeId) async {
    final result = await _client.get(
      '/places/recommend_times',
      query: {'place_id': placeId},
    );
    switch (result) {
      case ApiSuccess<Map<String, dynamic>>(data: final data):
        return ApiSuccess(RecommendTimesResponse.fromJson(data));
      case ApiFailure<Map<String, dynamic>>(message: final message):
        return ApiFailure(message);
      default:
        return const ApiFailure('Unknown error');
    }
  }
}
