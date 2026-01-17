import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/place.dart';
import '../../../data/models/search_request.dart';
import '../../../data/repositories/recommendations_repository.dart';
import '../../../data/repositories/search_repository.dart';

class SearchController extends ChangeNotifier {
  SearchController({
    SearchRepository? repository,
    RecommendationsRepository? recommendationsRepository,
    LocationService? locationService,
  })  : _repository = repository ?? SearchRepository(),
        _recommendationsRepository =
            recommendationsRepository ?? RecommendationsRepository(),
        _locationService = locationService ?? LocationService();

  final SearchRepository _repository;
  final RecommendationsRepository _recommendationsRepository;
  final LocationService _locationService;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 350));

  List<Place> results = [];
  List<Place> recommendedPlaces = []; // 추천 장소 리스트
  List<String> recentKeywords = [];
  bool isLoading = false;
  bool isLocationLoading = false; // 위치 정보 로딩 상태
  bool isRecommendationsLoading = false; // 추천 로딩 상태
  bool isExpandingRadius = false; // 반경 확대 중 상태
  int? currentSearchRadius; // 현재 검색 중인 반경 (km)
  String? error;
  String? recommendationsError;
  LocationData? _cachedLocation;
  Future<void>? _locationInitializationFuture; // 위치 초기화 Future 캐싱

  // 디버그 모드 상태 (정적 변수로 모든 인스턴스가 공유)
  static bool _useDebugMode = false; // true: 고정값 사용, false: 실제 API 값 사용
  static String? _debugCrowdingLevel; // 고정값으로 사용할 혼잡도 레벨 (null이면 실제 API 값 사용)
  
  bool get useDebugMode => _useDebugMode;
  String? get debugCrowdingLevel => _debugCrowdingLevel;
  
  /// 디버그 모드 토글
  void toggleDebugMode() {
    _useDebugMode = !_useDebugMode;
    if (!_useDebugMode) {
      _debugCrowdingLevel = null;
    }
    notifyListeners();
  }
  
  /// 디버그 모드에서 사용할 혼잡도 레벨 설정
  void setDebugCrowdingLevel(String? level) {
    _debugCrowdingLevel = level;
    notifyListeners();
  }

  void loadRecent() {
    recentKeywords = _repository.getRecentKeywords();
    notifyListeners();
  }

  /// 화면 진입 시 1회 호출하여 위치를 캐시
  /// 이미 초기화 중이면 기존 Future를 반환하여 중복 호출 방지
  Future<void> initializeLocation() async {
    if (_cachedLocation != null) {
      return; // 이미 캐시되어 있으면 즉시 반환
    }
    
    // 이미 초기화 중이면 기존 Future를 기다림
    if (_locationInitializationFuture != null) {
      await _locationInitializationFuture;
      return;
    }
    
    // 새로운 초기화 시작
    _locationInitializationFuture = _doInitializeLocation();
    await _locationInitializationFuture;
  }
  
  Future<void> _doInitializeLocation() async {
    try {
      isLocationLoading = true;
      notifyListeners();
      logInfo('Initializing location...');
      _cachedLocation = await _locationService.getCurrentPosition();
      logInfo('Location initialized: (${_cachedLocation!.latitude}, ${_cachedLocation!.longitude})');
      
      // 위치 초기화 후 추천 장소 로드
      await loadRecommendations();
    } catch (e) {
      logError('Location initialization failed', e.toString());
    } finally {
      isLocationLoading = false;
      notifyListeners();
    }
  }

  /// 목업 데이터 생성
  List<Place> _getMockRecommendations() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    return [
      Place(
        id: 'mock_1',
        name: '스타벅스 강남점',
        address: '서울특별시 강남구 테헤란로 123',
        latitude: 37.4979,
        longitude: 127.0276,
        category: '음식점 > 카페 > 커피전문점 > 스타벅스',
        distanceM: 250.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
        crowdingLevel: '여유',
        crowdingUpdatedAt: now - 300, // 5분 전
      ),
      Place(
        id: 'mock_2',
        name: '이디야커피 역삼점',
        address: '서울특별시 강남구 역삼동 456',
        latitude: 37.5000,
        longitude: 127.0300,
        category: '음식점 > 카페 > 커피전문점 > 이디야커피',
        distanceM: 450.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
        crowdingLevel: '보통',
        crowdingUpdatedAt: now - 180, // 3분 전
      ),
      Place(
        id: 'mock_3',
        name: '투썸플레이스 선릉점',
        address: '서울특별시 강남구 선릉로 789',
        latitude: 37.5040,
        longitude: 127.0490,
        category: '음식점 > 카페 > 커피전문점 > 투썸플레이스',
        distanceM: 680.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
        crowdingLevel: '여유',
        crowdingUpdatedAt: now - 420, // 7분 전
      ),
      Place(
        id: 'mock_4',
        name: '메가MGC커피 강남대로점',
        address: '서울특별시 강남구 강남대로 321',
        latitude: 37.4950,
        longitude: 127.0250,
        category: '음식점 > 카페 > 커피전문점 > 메가MGC커피',
        distanceM: 320.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
        crowdingLevel: '보통',
        crowdingUpdatedAt: now - 240, // 4분 전
      ),
      Place(
        id: 'mock_5',
        name: '할리스커피 강남역점',
        address: '서울특별시 강남구 강남대로 654',
        latitude: 37.4980,
        longitude: 127.0280,
        category: '음식점 > 카페 > 커피전문점 > 할리스커피',
        distanceM: 520.0,
        categoryGroupCode: 'CE7',
        imageUrl: '',
        crowdingLevel: '여유',
        crowdingUpdatedAt: now - 360, // 6분 전
      ),
    ];
  }

  /// 현재 위치 기반 추천 장소 로드 (반경 확대 방식)
  Future<void> loadRecommendations() async {
    // 목업 데이터 사용: API 호출 대신 항상 목업 데이터 반환
    try {
      isRecommendationsLoading = true;
      isExpandingRadius = false;
      currentSearchRadius = null;
      recommendationsError = null;
      notifyListeners();

      // 짧은 딜레이로 로딩 상태 시뮬레이션
      await Future.delayed(const Duration(milliseconds: 500));

      recommendedPlaces = _getMockRecommendations();
      logInfo('Mock recommendations loaded: ${recommendedPlaces.length} places');
      recommendationsError = null;
      isExpandingRadius = false;
      currentSearchRadius = null;
    } catch (e, stackTrace) {
      logError('Recommendations exception', '$e\n$stackTrace');
      recommendationsError = '추천 장소를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
      recommendedPlaces = [];
      isExpandingRadius = false;
      currentSearchRadius = null;
    } finally {
      isRecommendationsLoading = false;
      notifyListeners();
    }

    // 원래 API 호출 코드 (주석 처리)
    /*
    if (_cachedLocation == null) {
      return;
    }

    try {
      isRecommendationsLoading = true;
      isExpandingRadius = false;
      currentSearchRadius = null;
      recommendationsError = null;
      notifyListeners();

      logInfo('Loading recommendations at (${_cachedLocation!.latitude}, ${_cachedLocation!.longitude})');
      
      final result = await _recommendationsRepository.getRecommendations(
        lat: _cachedLocation!.latitude,
        lng: _cachedLocation!.longitude,
        category: 'cafe', // 기본값: 카페
        onRadiusChange: (radiusKm) {
          // 첫 번째 반경(3km) 이후부터는 확대 중 상태로 표시
          if (radiusKm > 3) {
            isExpandingRadius = true;
          }
          currentSearchRadius = radiusKm;
          notifyListeners();
        },
      );

      switch (result) {
        case ApiSuccess(data: final data):
          // 최대 10개까지만 표시
          recommendedPlaces = data.places.take(10).toList();
          logInfo('Recommendations loaded: ${recommendedPlaces.length} places');
          recommendationsError = null;
          isExpandingRadius = false;
          currentSearchRadius = null;
        case ApiFailure(message: final message):
          logError('Recommendations failed', message);
          recommendationsError = message;
          recommendedPlaces = [];
          isExpandingRadius = false;
          currentSearchRadius = null;
        default:
          logError('Recommendations failed', 'Unknown error');
          recommendationsError = '알 수 없는 오류가 발생했습니다.';
          recommendedPlaces = [];
          isExpandingRadius = false;
          currentSearchRadius = null;
      }
    } catch (e, stackTrace) {
      logError('Recommendations exception', '$e\n$stackTrace');
      recommendationsError = '추천 장소를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
      recommendedPlaces = [];
      isExpandingRadius = false;
      currentSearchRadius = null;
    } finally {
      isRecommendationsLoading = false;
      notifyListeners();
    }
    */
  }

  /// 디버깅용: 즉시 검색 수행 (debounce 없이)
  Future<List<Place>> searchImmediate(String keyword) async {
    if (_cachedLocation == null) {
      await initializeLocation();
    }

    final request = SearchRequest(
      query: keyword.trim(),
      lat: _cachedLocation!.latitude,
      lng: _cachedLocation!.longitude,
      size: 5,
      radiusM: 3000,
      // scope 기본값 'all' 사용, category_scope 기본값 'food_cafe' 사용
    );
    final res = await _repository.searchPlaces(request);
    switch (res) {
      case ApiSuccess<List<Place>>(data: final data):
        return data;
      case ApiFailure<List<Place>>(message: final message):
        logError('Search failed', message);
        return [];
      default:
        return [];
    }
  }

  void search(String keyword) {
    final trimmed = keyword.trim();
    
    if (trimmed.isEmpty) {
      results = [];
      isLoading = false;
      error = null;
      notifyListeners();
      return;
    }

    // 2자 미만이면 API 호출하지 않음
    if (trimmed.length < 2) {
      results = [];
      isLoading = false;
      error = null;
      notifyListeners();
      return;
    }

    _debouncer.run(() async {
      try {
        // 위치 정보가 없으면 초기화 (이미 초기화 중이면 기다림)
        if (_cachedLocation == null) {
          logInfo('Location not cached, waiting for initialization...');
          await initializeLocation();
        }

        if (_cachedLocation == null) {
          error = '위치 정보를 가져올 수 없습니다. 위치 권한을 확인해주세요.';
          isLoading = false;
          notifyListeners();
          return;
        }

        logInfo('Searching for: "${keyword.trim()}" at (${_cachedLocation!.latitude}, ${_cachedLocation!.longitude})');
        isLoading = true;
        error = null;
        notifyListeners();

        final request = SearchRequest(
          query: keyword.trim(),
          lat: _cachedLocation!.latitude,
          lng: _cachedLocation!.longitude,
          size: 5,
          radiusM: 3000,
          // scope 기본값 'all' 사용, category_scope 기본값 'food_cafe' 사용
        );
        final res = await _repository.searchPlaces(request);
        switch (res) {
          case ApiSuccess<List<Place>>(data: final data):
            logInfo('Search success: ${data.length} results');
            results = data;
            error = null;
          case ApiFailure<List<Place>>(message: final message):
            logError('Search failed', message);
            error = message;
            results = [];
          default:
            logError('Search failed', 'Unknown error');
            error = '알 수 없는 오류가 발생했습니다.';
            results = [];
        }
      } catch (e, stackTrace) {
        logError('Search exception', '$e\n$stackTrace');
        error = '검색 중 오류가 발생했습니다: ${e.toString()}';
        results = [];
      } finally {
        isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}




