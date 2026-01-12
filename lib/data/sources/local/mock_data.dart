import '../../models/insight_response.dart';
import '../../models/place.dart';
import '../../models/place_with_zone.dart';
import '../../models/search_response.dart';
import '../../models/zone_info.dart';

/// 백엔드 API 공사 중 테스트용 하드코딩 데이터
class MockData {
  /// 검색 결과: 스타벅스 가산에스케이점 (사용자 선택 매장)
  /// 주소: 서울특별시 금천구 가산디지털1로 171, 가산 에스케이 브이원 센터
  static Place get selectedStore => const Place(
        id: 'mock_starbucks_gasan_sk',
        name: '스타벅스 가산에스케이점',
        address: '서울특별시 금천구 가산디지털1로 171',
        latitude: 37.4775,
        longitude: 126.8810,
        category: '카페',
        distanceM: 0.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
      );

  /// 선택 매장의 ZoneInfo (기본 혼잡도: 붐빔)
  static ZoneInfo get selectedStoreZone => const ZoneInfo(
        code: 'mock_zone_1',
        name: '가산디지털단지',
        lat: 37.4775,
        lng: 126.8810,
        distanceM: 0.0,
        crowdingLevel: '붐빔',
        crowdingRank: 1,
        crowdingColor: 'red',
        crowdingUpdatedAt: 0,
        crowdingMessage: '현재 붐빔 상태입니다',
      );

  /// 추천 매장 1: 스타벅스 가산디지털점네이버페이
  /// 주소: 서울특별시 금천구 가산디지털1로 145, 에이스하이엔드타워3
  static Place get recommendedStore1 => const Place(
        id: 'mock_starbucks_gasan_digital',
        name: '스타벅스 가산디지털점네이버페이',
        address: '서울특별시 금천구 가산디지털1로 145',
        latitude: 37.4810,
        longitude: 126.8865,
        category: '카페',
        distanceM: 450.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
      );

  static ZoneInfo get recommendedStore1Zone => const ZoneInfo(
        code: 'mock_zone_2',
        name: '가산디지털단지',
        lat: 37.4810,
        lng: 126.8865,
        distanceM: 450.0,
        crowdingLevel: '여유',
        crowdingRank: 4,
        crowdingColor: 'green',
        crowdingUpdatedAt: 0,
        crowdingMessage: '현재 여유로운 상태입니다',
      );

  /// 추천 매장 2: 메가MGC커피 가산SKV1점
  static Place get recommendedStore2 => const Place(
        id: 'mock_mega_mgc_gasan_skv1',
        name: '메가MGC커피 가산SKV1점',
        address: '서울특별시 금천구 가산디지털1로',
        latitude: 37.4770,
        longitude: 126.8895,
        category: '카페',
        distanceM: 680.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
      );

  static ZoneInfo get recommendedStore2Zone => const ZoneInfo(
        code: 'mock_zone_3',
        name: '가산디지털단지',
        lat: 37.4770,
        lng: 126.8895,
        distanceM: 680.0,
        crowdingLevel: '여유',
        crowdingRank: 4,
        crowdingColor: 'green',
        crowdingUpdatedAt: 0,
        crowdingMessage: '현재 여유로운 상태입니다',
      );

  /// 추천 매장 3: 빽다방 가산SKV1점
  static Place get recommendedStore3 => const Place(
        id: 'mock_baek_dabang_gasan_skv1',
        name: '빽다방 가산SKV1점',
        address: '서울특별시 금천구 가산디지털1로',
        latitude: 37.4795,
        longitude: 126.8850,
        category: '카페',
        distanceM: 320.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
      );

  static ZoneInfo get recommendedStore3Zone => const ZoneInfo(
        code: 'mock_zone_4',
        name: '가산디지털단지',
        lat: 37.4795,
        lng: 126.8850,
        distanceM: 320.0,
        crowdingLevel: '여유',
        crowdingRank: 4,
        crowdingColor: 'green',
        crowdingUpdatedAt: 0,
        crowdingMessage: '현재 여유로운 상태입니다',
      );

  /// 검색 결과 반환 (스타벅스 가산에스케이점)
  static SearchResponse getSearchResponse() {
    return SearchResponse(
      places: [selectedStore],
      totalCount: 1,
    );
  }

  /// 인사이트 응답 반환 (선택 매장 + 추천 매장 3곳)
  static PlacesInsightResponse getInsightResponse() {
    return PlacesInsightResponse(
      selected: PlaceWithZone(
        place: selectedStore,
        zone: selectedStoreZone,
      ),
      alternatives: [
        PlaceWithZone(
          place: recommendedStore1,
          zone: recommendedStore1Zone,
        ),
        PlaceWithZone(
          place: recommendedStore2,
          zone: recommendedStore2Zone,
        ),
        PlaceWithZone(
          place: recommendedStore3,
          zone: recommendedStore3Zone,
        ),
      ],
    );
  }
}
