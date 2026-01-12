import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../local/mock_data.dart';
import '../../models/insight_request.dart';
import '../../models/insight_response.dart';

class InsightApi {
  InsightApi({HttpClient? client})
      : _client = client ??
            HttpClient(baseUrl: dotenv.env[Env.apiBaseUrl] ?? 'http://127.0.0.1:8000');

  final HttpClient _client;

  // TODO: 백엔드 API 공사 완료 후 실제 API 호출로 변경
  static const bool _useMockData = true;

  Future<ApiResult<PlacesInsightResponse>> getInsight(PlacesInsightRequest request) async {
    // 백엔드 API 공사 중: 하드코딩된 데이터 반환
    if (_useMockData) {
      await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
      return ApiSuccess(MockData.getInsightResponse());
    }

    // 실제 API 호출 (공사 완료 후 사용)
    final result = await _client.post(
      '/places/insight',
      body: request.toJson(),
    );
    switch (result) {
      case ApiSuccess<Map<String, dynamic>>(data: final data):
        return ApiSuccess(PlacesInsightResponse.fromJson(data));
      case ApiFailure<Map<String, dynamic>>(message: final message):
        return ApiFailure(message);
      default:
        return const ApiFailure('Unknown error');
    }
  }
}
