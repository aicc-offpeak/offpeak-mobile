import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../../models/search_request.dart';
import '../../models/search_response.dart';

class SearchApi {
  SearchApi({HttpClient? client})
      : _client = client ??
            HttpClient(baseUrl: dotenv.env[Env.apiBaseUrl] ?? 'http://localhost');

  final HttpClient _client;

  Future<ApiResult<SearchResponse>> search(SearchRequest request) async {
    final result = await _client.get('/search', query: request.toQuery());
    switch (result) {
      case ApiSuccess<Map<String, dynamic>>(data: final data):
        return ApiSuccess(SearchResponse.fromJson(data));
      case ApiFailure<Map<String, dynamic>>(message: final message):
        return ApiFailure(message);
      default:
        return const ApiFailure('Unknown error');
    }
  }
}




