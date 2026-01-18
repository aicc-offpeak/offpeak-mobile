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
    // 목업 시간대 데이터 반환 (5개 시간대)
    // 5개의 시간대 생성 (다양한 요일과 시간대)
    final mockData = {
      'place_id': placeId,
      'tz': 'Asia/Seoul',
      'days': 7,
      'min_samples': 3,
      'per_day': 3,
      'window_h': 2,
      'include_low_samples': false,
      'fallback_to_hourly': false,
      'total_samples': 15,
      'recommendations': [
        // 월요일: 오전 10시-12시
        {
          'dow': 1,
          'dow_name': '월',
          'windows': [
            {
              'dow': 1,
              'dow_name': '월',
              'start_hour': 10,
              'end_hour': 12,
              'label': '오전',
              'avg_rank': 3.5,
              'n': 5,
              'hours': [10, 11],
              'mode_level': '보통',
              'fallback': false,
              'confidence': 'medium',
              'reason': '평일 오전 시간대는 상대적으로 여유로워요',
            },
          ],
        },
        // 화요일: 오후 2시-4시
        {
          'dow': 2,
          'dow_name': '화',
          'windows': [
            {
              'dow': 2,
              'dow_name': '화',
              'start_hour': 14,
              'end_hour': 16,
              'label': '오후',
              'avg_rank': 3.8,
              'n': 6,
              'hours': [14, 15],
              'mode_level': '여유',
              'fallback': false,
              'confidence': 'high',
              'reason': '점심 시간 이후로 한산한 시간대예요',
            },
          ],
        },
        // 수요일: 오전 9시-11시
        {
          'dow': 3,
          'dow_name': '수',
          'windows': [
            {
              'dow': 3,
              'dow_name': '수',
              'start_hour': 9,
              'end_hour': 11,
              'label': '오전',
              'avg_rank': 3.2,
              'n': 4,
              'hours': [9, 10],
              'mode_level': '보통',
              'fallback': false,
              'confidence': 'medium',
              'reason': '출근 시간 이후 비교적 한산해요',
            },
          ],
        },
        // 목요일: 오후 3시-5시
        {
          'dow': 4,
          'dow_name': '목',
          'windows': [
            {
              'dow': 4,
              'dow_name': '목',
              'start_hour': 15,
              'end_hour': 17,
              'label': '오후',
              'avg_rank': 4.0,
              'n': 7,
              'hours': [15, 16],
              'mode_level': '여유',
              'fallback': false,
              'confidence': 'high',
              'reason': '평일 오후 시간대 중 가장 여유로워요',
            },
          ],
        },
        // 금요일: 오전 11시-1시
        {
          'dow': 5,
          'dow_name': '금',
          'windows': [
            {
              'dow': 5,
              'dow_name': '금',
              'start_hour': 11,
              'end_hour': 13,
              'label': '정오',
              'avg_rank': 3.6,
              'n': 5,
              'hours': [11, 12],
              'mode_level': '보통',
              'fallback': false,
              'confidence': 'medium',
              'reason': '금요일 점심 시간대는 보통 수준이에요',
            },
          ],
        },
      ],
    };
    
    return ApiSuccess(RecommendTimesResponse.fromJson(mockData));
    
    // 원래 코드 (주석 처리)
    // final result = await _client.get(
    //   '/places/recommend_times',
    //   query: {'place_id': placeId},
    // );
    // switch (result) {
    //   case ApiSuccess<Map<String, dynamic>>(data: final data):
    //     return ApiSuccess(RecommendTimesResponse.fromJson(data));
    //   case ApiFailure<Map<String, dynamic>>(message: final message):
    //     return ApiFailure(message);
    //   default:
    //     return const ApiFailure('Unknown error');
    // }
  }
}
