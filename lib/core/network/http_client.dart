import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_result.dart';
import 'exceptions.dart';

/// Lightweight wrapper to centralize FastAPI calls.
class HttpClient {
  HttpClient({required this.baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        );

  final String baseUrl;
  final Dio _dio;

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      print('[HttpClient] GET $baseUrl$path');
      print('[HttpClient] Query: $query');
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
      print('[HttpClient] GET DioException: ${e.type} - ${e.message}');
      print('[HttpClient] Error details: ${e.toString()}');
      if (e.error != null) print('[HttpClient] Error: ${e.error}');
      return ApiFailure(_normalizeDioError(e));
    } catch (e) {
      print('[HttpClient] GET Exception: $e');
      return ApiFailure(_normalizeError(e));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      print('[HttpClient] POST $baseUrl$path');
      print('[HttpClient] Body: $body');
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
        final errorBody = response.data?.toString() ?? 'No error body';
        print('[HttpClient] POST Error Response: $errorBody');
        return ApiFailure('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('[HttpClient] POST DioException: ${e.type} - ${e.message}');
      if (e.response != null) {
        print('[HttpClient] Error Response Status: ${e.response!.statusCode}');
        print('[HttpClient] Error Response Body: ${e.response!.data}');
      }
      print('[HttpClient] Error details: ${e.toString()}');
      if (e.error != null) print('[HttpClient] Error: ${e.error}');
      return ApiFailure(_normalizeDioError(e));
    } catch (e) {
      print('[HttpClient] POST Exception: $e');
      return ApiFailure(_normalizeError(e));
    }
  }

  String _normalizeDioError(DioException e) {
    if (e.response != null) {
      return 'HTTP ${e.response!.statusCode}: ${e.response!.statusMessage}';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timeout: 서버에 연결할 수 없습니다. '
          '서버가 실행 중인지, 네트워크 연결을 확인하세요. '
          '(Base URL: $baseUrl)';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Connection error: 서버에 연결할 수 없습니다. '
          '서버 주소($baseUrl)가 올바른지 확인하세요. '
          '실기기에서는 localhost 대신 실제 서버 IP나 도메인을 사용해야 합니다.';
    }
    return '${e.message ?? 'Network error'} (Base URL: $baseUrl)';
  }

  String _normalizeError(Object e) {
    if (e is ApiException) return e.message;
    return 'Unexpected error: $e';
  }
}




