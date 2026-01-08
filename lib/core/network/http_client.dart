import 'dart:convert';

import 'api_result.dart';
import 'exceptions.dart';

/// Lightweight wrapper to centralize FastAPI calls.
class HttpClient {
  HttpClient({required this.baseUrl});

  final String baseUrl;

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      // TODO: integrate package:http or dio
      return ApiSuccess({'path': '$baseUrl$path', 'query': query ?? {}});
    } catch (e) {
      return ApiFailure(_normalizeError(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final encoded = jsonEncode(body ?? {});
      // TODO: integrate package:http or dio
      return ApiSuccess(
        {'path': '$baseUrl$path', 'headers': headers ?? {}, 'body': encoded},
      );
    } catch (e) {
      return ApiFailure(_normalizeError(e));
    }
  }

  String _normalizeError(Object e) {
    if (e is ApiException) return e.message;
    return 'Unexpected error: $e';
  }
}




