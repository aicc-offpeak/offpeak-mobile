import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_result.dart';
import 'exceptions.dart';

/// Lightweight wrapper to centralize FastAPI calls.
class HttpClient {
  HttpClient({required this.baseUrl}) : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  final String baseUrl;
  final Dio _dio;

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return ApiSuccess(data);
        }
        return ApiFailure('Invalid response format');
      } else {
        return ApiFailure('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      return ApiFailure(_normalizeDioError(e));
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
      final response = await _dio.post(
        path,
        data: body,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return ApiSuccess(data);
        }
        return ApiFailure('Invalid response format');
      } else {
        return ApiFailure('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      return ApiFailure(_normalizeDioError(e));
    } catch (e) {
      return ApiFailure(_normalizeError(e));
    }
  }

  String _normalizeDioError(DioException e) {
    if (e.response != null) {
      return 'HTTP ${e.response!.statusCode}: ${e.response!.statusMessage}';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Connection error';
    }
    return e.message ?? 'Network error';
  }

  String _normalizeError(Object e) {
    if (e is ApiException) return e.message;
    return 'Unexpected error: $e';
  }
}




