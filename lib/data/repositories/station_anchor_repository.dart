import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/constants/env.dart';

/// Kakao Local REST API를 사용하여 근처 지하철역을 조회하는 Repository
class StationAnchorRepository {
  static const String _baseUrl = 'https://dapi.kakao.com';
  static const String _categoryGroupCode = 'SW8'; // 지하철역
  static const int _initialRadius = 500; // 초기 반경 500m
  static const int _expandedRadius = 1000; // 확대 반경 1000m

  final Dio _dio;

  StationAnchorRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// 현재 위치 근처의 가장 가까운 지하철역 이름을 조회
  /// 
  /// [latitude] 위도
  /// [longitude] 경도
  /// 
  /// 반환: 역명 (역 접미사 포함, 중복 방지 처리됨), 실패 시 null
  Future<String?> fetchNearestStationName(
    double latitude,
    double longitude,
  ) async {
    final apiKey = dotenv.env[Env.kakaoRestApiKey];
    if (apiKey == null || apiKey.isEmpty) {
      print('[StationAnchorRepository] KAKAO_REST_API_KEY가 설정되지 않았습니다.');
      return null;
    }

    // 500m 반경으로 먼저 시도
    String? stationName = await _fetchWithRadius(
      latitude,
      longitude,
      _initialRadius,
      apiKey,
    );

    // 결과가 없으면 1000m로 1회만 확대 재시도
    if (stationName == null) {
      stationName = await _fetchWithRadius(
        latitude,
        longitude,
        _expandedRadius,
        apiKey,
      );
    }

    return stationName;
  }

  Future<String?> _fetchWithRadius(
    double latitude,
    double longitude,
    int radius,
    String apiKey,
  ) async {
    try {
      final response = await _dio.get(
        '/v2/local/search/category.json',
        queryParameters: {
          'category_group_code': _categoryGroupCode,
          'x': longitude.toString(),
          'y': latitude.toString(),
          'radius': radius.toString(),
          'sort': 'distance',
        },
        options: Options(
          headers: {
            'Authorization': 'KakaoAK $apiKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final documents = data['documents'] as List?;
          if (documents != null && documents.isNotEmpty) {
            // 가장 가까운 결과 1개만 사용 (sort=distance로 이미 정렬됨)
            final firstResult = documents[0] as Map<String, dynamic>;
            final placeName = firstResult['place_name'] as String?;
            if (placeName != null && placeName.isNotEmpty) {
              return _normalizeStationName(placeName);
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('[StationAnchorRepository] Error: $e');
      return null;
    }
  }

  /// 역명에서 "역" 접미사 중복을 방지
  /// 예: "강남역" -> "강남역", "강남" -> "강남역"
  String _normalizeStationName(String placeName) {
    final trimmed = placeName.trim();
    if (trimmed.endsWith('역')) {
      return trimmed;
    }
    return '$trimmed역';
  }
}
