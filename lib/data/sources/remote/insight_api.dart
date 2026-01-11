import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../../models/insight_request.dart';
import '../../models/insight_response.dart';

class InsightApi {
  InsightApi({HttpClient? client})
      : _client = client ??
            HttpClient(baseUrl: dotenv.env[Env.apiBaseUrl] ?? 'http://127.0.0.1:8000');

  final HttpClient _client;

  Future<ApiResult<PlacesInsightResponse>> getInsight(PlacesInsightRequest request) async {
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
