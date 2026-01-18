import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/env.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/http_client.dart';
import '../../models/insight_request.dart';
import '../../models/insight_response.dart';

class InsightApi {
  InsightApi({HttpClient? client}) : _client = client ?? _createClient();

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

  Future<ApiResult<PlacesInsightResponse>> getInsight(PlacesInsightRequest request) async {
    // 목업 데이터 반환 (하드코딩된 가산디지털단지역 좌표 사용)
    // 위도: 37.481519493, 경도: 126.882630605
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // 요청에서 선택된 장소 정보 가져오기 (없으면 기본값 사용)
    final selectedPlace = request.selected;
    
    // 목업 데이터 생성
    final mockData = {
      'selected': {
        'place': {
          'id': selectedPlace.id,
          'name': selectedPlace.name,
          'address_name': selectedPlace.address.isNotEmpty ? selectedPlace.address : '서울특별시 금천구 가산디지털1로 123',
          'lat': selectedPlace.latitude,
          'lng': selectedPlace.longitude,
          'category_name': selectedPlace.category.isNotEmpty ? selectedPlace.category : '음식점 > 카페 > 커피전문점',
          'distance_m': selectedPlace.distanceM,
          'category_group_code': selectedPlace.categoryGroupCode.isNotEmpty ? selectedPlace.categoryGroupCode : 'CE7',
          'image_url': selectedPlace.imageUrl,
        },
        'zone': {
          'code': 'HARDCODED_GASAN',
          'name': '가산디지털단지역',
          'lat': 37.481519493,
          'lng': 126.882630605,
          'distance_m': 0.0,
          'crowding_level': '여유',
          'crowding_rank': 4,
          'crowding_color': 'green',
          'crowding_updated_at': now - 300, // 5분 전
          'crowding_message': '현재 여유로운 상태입니다',
        },
      },
      'alternatives': [
        {
          'place': {
            'id': 'mock_alt_1',
            'name': '스타벅스 가산디지털단지점',
            'address_name': '서울특별시 금천구 가산디지털1로 145',
            'lat': 37.4820,
            'lng': 126.8830,
            'category_name': '음식점 > 카페 > 커피전문점 > 스타벅스',
            'distance_m': 150.0,
            'category_group_code': 'CE7',
            'image_url': '',
          },
          'zone': {
            'code': 'HARDCODED_GASAN',
            'name': '가산디지털단지역',
            'lat': 37.481519493,
            'lng': 126.882630605,
            'distance_m': 150.0,
            'crowding_level': '보통',
            'crowding_rank': 3,
            'crowding_color': 'yellow',
            'crowding_updated_at': now - 180,
            'crowding_message': '현재 보통 상태입니다',
          },
        },
        {
          'place': {
            'id': 'mock_alt_2',
            'name': '이디야커피 가산점',
            'address_name': '서울특별시 금천구 가산디지털1로 167',
            'lat': 37.4830,
            'lng': 126.8840,
            'category_name': '음식점 > 카페 > 커피전문점 > 이디야커피',
            'distance_m': 250.0,
            'category_group_code': 'CE7',
            'image_url': '',
          },
          'zone': {
            'code': 'HARDCODED_GASAN',
            'name': '가산디지털단지역',
            'lat': 37.481519493,
            'lng': 126.882630605,
            'distance_m': 250.0,
            'crowding_level': '여유',
            'crowding_rank': 4,
            'crowding_color': 'green',
            'crowding_updated_at': now - 240,
            'crowding_message': '현재 여유로운 상태입니다',
          },
        },
        {
          'place': {
            'id': 'mock_alt_3',
            'name': '투썸플레이스 가산점',
            'address_name': '서울특별시 금천구 가산디지털1로 189',
            'lat': 37.4840,
            'lng': 126.8850,
            'category_name': '음식점 > 카페 > 커피전문점 > 투썸플레이스',
            'distance_m': 350.0,
            'category_group_code': 'CE7',
            'image_url': '',
          },
          'zone': {
            'code': 'HARDCODED_GASAN',
            'name': '가산디지털단지역',
            'lat': 37.481519493,
            'lng': 126.882630605,
            'distance_m': 350.0,
            'crowding_level': '보통',
            'crowding_rank': 3,
            'crowding_color': 'yellow',
            'crowding_updated_at': now - 360,
            'crowding_message': '현재 보통 상태입니다',
          },
        },
      ],
    };
    
    return ApiSuccess(PlacesInsightResponse.fromJson(mockData));
    
    // 원래 코드 (주석 처리)
    // final result = await _client.post(
    //   '/places/insight',
    //   body: request.toJson(),
    // );
    // switch (result) {
    //   case ApiSuccess<Map<String, dynamic>>(data: final data):
    //     return ApiSuccess(PlacesInsightResponse.fromJson(data));
    //   case ApiFailure<Map<String, dynamic>>(message: final message):
    //     return ApiFailure(message);
    //   default:
    //     return const ApiFailure('Unknown error');
    // }
  }
}
