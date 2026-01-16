import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../../core/constants/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/brand_icon_mapper.dart';
import '../../../data/models/insight_request.dart';
import '../../../data/models/insight_response.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_with_zone.dart';
import '../../../data/models/recommend_times_response.dart';
import '../../../data/models/zone_info.dart';
import '../../../data/repositories/insight_repository.dart';
import '../../../data/repositories/recommend_times_repository.dart';
import '../../search/state/search_controller.dart' as search;
import '../widgets/map_view.dart';

/// Design tokens for the result map screen
class _DesignTokens {
  // Colors
  static const Color primary = Color(0xFF007AFF);
  static const Color warning = Color(0xFFFF6B35);
  static const Color success = Color(0xFF2E7D32);
  static const Color grayBg = Color(0xFFF5F5F5); // #F9F9F9 → #F5F5F5
  static const Color grayBorder = Color(0xFFE0E0E0);
  static const Color grayText = Color(0xFF666666);
  static const Color grayTextTertiary = Color(0xFF999999); // 추가
  static const Color black = Color(0xFF1A1A1A);
  static const Color brandIconBg = Color(0xFFFFD700); // #FFD700
  static const Color handleColor = Color(0xFFD1D1D6); // 핸들 색상
  
  // Badge colors
  static const Map<String, Map<String, Color>> badgeColors = {
    '여유': {'bg': Color(0xFFD0F6B9), 'text': Color(0xFE1C9E40)}, 
    '보통': {'bg': Color(0xFFFFE894), 'text': Color(0xFFF59C00)}, // 원래대로 복구
    '약간 붐빔': {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFFF6B35)},
    '붐빔': {'bg': Color(0xFFFFEBEE), 'text': Color(0xFFD32F2F)},
  };
  
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0; // 추가
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0; // 추가
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  
  // Border radius
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
}

/// 뷰 상태 enum
enum ViewState {
  baseSelectedView,
  tempSelectedFromRecommendation,
}

/// TIME 탭 상태
enum TimeTabState {
  loading,
  success,
  empty,
  error,
}

/// PLACE 탭 상태
enum PlaceTabState {
  loading,
  success,
  emptyFirst,
  emptyExpanded,
  error,
}

/// 반경 모드
enum RadiusMode {
  base,      // 500m
  expanded,  // 1000m
}

/// Decision-focused result screen showing map with congestion information
class ResultMapScreen extends StatefulWidget {
  final Place? selectedPlace;

  const ResultMapScreen({super.key, this.selectedPlace});

  @override
  State<ResultMapScreen> createState() => _ResultMapScreenState();
}

class _ResultMapScreenState extends State<ResultMapScreen>
    with SingleTickerProviderStateMixin {
  final _insightRepository = InsightRepository();
  final _recommendTimesRepository = RecommendTimesRepository();
  final _locationService = LocationService();
  final _searchController = search.SearchController(); // 디버그 모드 설정 접근용

  // 지도 컨트롤러 관련
  KakaoMapController? _mapController;
  bool _mapReady = false;

  PlacesInsightResponse? _insightData;
  bool _isLoading = false;
  bool _showLongLoadingIndicator = false; // 3초 이상 로딩 시 원형 프로그레스바 표시
  DateTime? _loadingStartTime; // 로딩 시작 시간 추적
  bool _showSecondLoadingMessage = false; // 0.5초 후 두 번째 메시지 표시 여부
  Place? _currentSelectedPlace; // 현재 선택된 장소 (recommended place 선택 시 업데이트)
  late AnimationController _animationController; // 애니메이션 컨트롤러
  RecommendTimesResponse? _recommendTimesData; // 추천 시간대 데이터
  String _selectedTab = 'place'; // 하단 시트의 선택된 탭 ('time' or 'place')
  
  // 탭별 상태 관리
  TimeTabState _timeTabState = TimeTabState.loading;
  PlaceTabState _placeTabState = PlaceTabState.loading;
  RadiusMode _placeRadiusMode = RadiusMode.base; // PLACE 탭 반경 모드
  String? _timeTabError; // TIME 탭 에러 메시지
  String? _placeTabError; // PLACE 탭 에러 메시지
  
  // 범위 확대 상태 관리
  int _currentSearchRadiusM = 500; // 내부 검색 반경 (500/1200/2000)
  String _lastExpandStep = 'none'; // 'none' | 'step1' | 'step2'
  bool _isLoadingExpand = false; // 범위 확대 중 로딩 상태
  
  // 임시 선택 상태 관리
  ViewState _viewState = ViewState.baseSelectedView;
  PlaceWithZone? _baseSelectedPlaceWithZone; // 원래 선택된 장소 (스냅샷)
  List<PlaceWithZone> _baseRecommendations = []; // 원래 추천 리스트 (스냅샷)
  PlaceWithZone? _tempSelectedPlaceWithZone; // 임시 선택된 장소
  
  // 하단 카드 접기/펼치기 상태 (기본값: 펼침)
  bool _isBottomSheetExpanded = true;
  
  // 하단 시트 스크롤 컨트롤러
  final ScrollController _bottomSheetScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _currentSelectedPlace = widget.selectedPlace;
    if (_currentSelectedPlace != null) {
      _loadInsight();
      // TIME 탭이 기본 선택되어 있으면 시간 데이터도 로드
      if (_selectedTab == 'time') {
        _loadRecommendTimes();
      }
    }
  }
  
  /// 탭 전환 핸들러
  void _onTabChanged(String tab) {
    setState(() {
      _selectedTab = tab;
    });
    
    // 탭 전환 시 해당 탭의 데이터 로드
    if (tab == 'time') {
      if (_timeTabState != TimeTabState.success || _recommendTimesData == null) {
        _loadRecommendTimes();
      }
    } else if (tab == 'place') {
      if (_placeTabState != PlaceTabState.success || _insightData == null) {
        _loadInsight();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _bottomSheetScrollController.dispose();
    _mapController = null;
    _mapReady = false;
    super.dispose();
  }

  /// API 데이터를 로드 (PLACE 탭용)
  Future<void> _loadInsight({bool isRetry = false}) async {
    if (_currentSelectedPlace == null) return;

    // PLACE 탭이 활성화되어 있을 때만 상태 업데이트
    if (_selectedTab == 'place' && !isRetry) {
      setState(() {
        _placeTabState = PlaceTabState.loading;
        _placeTabError = null;
      });
    }

    setState(() {
      _isLoading = true;
      _showLongLoadingIndicator = false;
      _showSecondLoadingMessage = false;
      _loadingStartTime = DateTime.now(); // 로딩 시작 시간 기록
    });

    // 0.5초 후 두 번째 메시지로 전환
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isLoading && mounted) {
        setState(() {
          _showSecondLoadingMessage = true;
        });
      }
    });

    // 3초 후에도 로딩 중이면 원형 프로그레스바 표시
    Future.delayed(const Duration(seconds: 3), () {
      if (_isLoading && mounted) {
        setState(() {
          _showLongLoadingIndicator = true;
        });
      }
    });

    try {
      final location = await _locationService.getCurrentPosition();
      // 내부 검색 반경 사용 (UI에는 항상 1km로 표기)
      final request = PlacesInsightRequest(
        selected: _currentSelectedPlace!,
        userLat: location.latitude,
        userLng: location.longitude,
        radiusM: _currentSearchRadiusM,
        maxAlternatives: 3,
      );

      final result = await _insightRepository.getInsight(request);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<PlacesInsightResponse>():
            var insightData = result.data;
            final alternatives = insightData.alternatives;
            
            // 디버그 모드가 활성화되어 있고 고정값이 설정되어 있으면 혼잡도 덮어쓰기
            if (_searchController.useDebugMode && _searchController.debugCrowdingLevel != null) {
              final debugLevel = _searchController.debugCrowdingLevel!;
              // 검색 매장의 혼잡도만 고정값으로 변경
              final updatedSelected = PlaceWithZone(
                place: insightData.selected.place,
                zone: insightData.selected.zone.copyWithCrowdingLevel(debugLevel),
              );
              insightData = PlacesInsightResponse(
                selected: updatedSelected,
                alternatives: alternatives,
              );
            }
            
            final isCongested = insightData.selected.zone.isCongested;
            
            setState(() {
              _insightData = insightData;
              _isLoading = false;
              _showLongLoadingIndicator = false;
              _showSecondLoadingMessage = false;
              _loadingStartTime = null;
              
              // PLACE 탭 상태 업데이트
              if (_selectedTab == 'place') {
                final hadResults = alternatives.isNotEmpty;
                if (alternatives.isEmpty) {
                  if (_lastExpandStep == 'none') {
                    _placeTabState = PlaceTabState.emptyFirst;
                  } else {
                    _placeTabState = PlaceTabState.emptyExpanded;
                  }
                } else {
                  _placeTabState = PlaceTabState.success;
                  // 범위 확대 후 결과가 있으면 스크롤 상단으로 이동
                  if (_lastExpandStep != 'none' && hadResults) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_bottomSheetScrollController.hasClients) {
                        _bottomSheetScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }
                }
              }
              
              // 검색 매장과 추천 매장 스냅샷 캡처 (한 번만, API 성공 시)
              if (_baseSelectedPlaceWithZone == null) {
                _baseSelectedPlaceWithZone = insightData.selected;
                _baseRecommendations = List.from(alternatives);
              }
            });
            // 혼잡 상태가 변경되면 애니메이션 재시작
            if (isCongested) {
              _animationController.forward();
            } else {
              _animationController.reset();
            }
          case ApiFailure<PlacesInsightResponse>():
            if (_selectedTab == 'place') {
              setState(() {
                _placeTabState = PlaceTabState.error;
                _placeTabError = result.message;
              });
            } else {
              // API 실패 시 디버깅 모드로 전환 (초기 로드 시에만)
            _loadDebugModeData();
            }
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        if (_selectedTab == 'place') {
          setState(() {
            _placeTabState = PlaceTabState.error;
            _placeTabError = e.toString();
          });
        } else {
          // 예외 발생 시 디버깅 모드로 전환 (초기 로드 시에만)
        _loadDebugModeData();
        }
      }
    }
  }
  
  /// 반경 확장 및 재조회 (2000m로 확장)
  Future<void> _expandRadiusAndRefetch() async {
    if (_isLoadingExpand) return; // 중복 탭 방지
    
    setState(() {
      _isLoadingExpand = true;
      _placeTabState = PlaceTabState.loading;
      _placeTabError = null;
      _currentSearchRadiusM = 2000; // 2km로 확장
      _lastExpandStep = 'step2';
    });
    
    try {
      // API 호출 (2000m 반경으로 재검색)
      await _loadInsight();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExpand = false;
        });
      }
    }
  }
  
  /// 시간 바꾸기 탭으로 전환
  void _openTimeRecommendation() {
    setState(() {
      _selectedTab = 'time';
    });
    if (_timeTabState != TimeTabState.success || _recommendTimesData == null) {
      _loadRecommendTimes();
    }
  }
  
  /// PLACE 탭 재시도
  Future<void> _retryPlace() async {
    setState(() {
      _placeTabState = PlaceTabState.loading;
      _placeTabError = null;
    });
    await _loadInsight(isRetry: true);
  }
  
  /// TIME 탭 재시도
  Future<void> _retryTime() async {
    await _loadRecommendTimes();
  }

  /// 디버깅 모드 데이터 로드
  /// API 실패 시 사용되는 mock 데이터
  void _loadDebugModeData() {
    if (_currentSelectedPlace == null) return;

    // 검색 매장: base 스냅샷이 있으면 사용, 없으면 현재 선택된 장소 사용
    final basePlace = _baseSelectedPlaceWithZone?.place ?? _currentSelectedPlace!;
    final defaultCrowdingLevel = '붐빔'; // 기본 혼잡도
    final baseZone = _baseSelectedPlaceWithZone?.zone ?? ZoneInfo(
      code: 'debug_selected',
      name: basePlace.name,
      lat: basePlace.latitude,
      lng: basePlace.longitude,
      distanceM: basePlace.distanceM,
      crowdingLevel: defaultCrowdingLevel,
      crowdingRank: defaultCrowdingLevel == '붐빔' ? 1 : 
                    defaultCrowdingLevel == '약간 붐빔' ? 2 :
                    defaultCrowdingLevel == '보통' ? 3 : 4,
      crowdingColor: defaultCrowdingLevel == '붐빔' ? 'red' :
                     defaultCrowdingLevel == '약간 붐빔' ? 'orange' :
                     defaultCrowdingLevel == '보통' ? 'yellow' : 'green',
      crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      crowdingMessage: '디버깅 모드',
    );
    
    // 검색 매장의 혼잡도만 업데이트
    final selectedZone = baseZone.copyWithCrowdingLevel(defaultCrowdingLevel);

    // 추천 매장 3곳 하드코딩 (가산 지역)
    final recommendedPlaces = [
      // 매장1: 스타벅스, 혼잡도-여유
      PlaceWithZone(
        place: Place(
          id: 'debug_starbucks',
          name: '스타벅스 가산에스케이점',
          address: '서울특별시 금천구 가산동',
          latitude: 37.4785,
          longitude: 126.8876,
          category: '카페',
          distanceM: 500.0,
          categoryGroupCode: 'CE7',
        ),
        zone: ZoneInfo(
          code: 'debug_starbucks_zone',
          name: '스타벅스 가산에스케이점',
          lat: 37.4785,
          lng: 126.8876,
          distanceM: 500.0,
          crowdingLevel: '여유',
          crowdingRank: 4,
          crowdingColor: 'green',
          crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          crowdingMessage: '디버깅 모드',
        ),
      ),
      // 매장2: 빽다방, 혼잡도-여유
      PlaceWithZone(
        place: Place(
          id: 'debug_paikdabang',
          name: '빽다방 가산디지털단지역점',
          address: '서울특별시 금천구 가산동',
          latitude: 37.4800,
          longitude: 126.8900,
          category: '카페',
          distanceM: 600.0,
          categoryGroupCode: 'CE7',
        ),
        zone: ZoneInfo(
          code: 'debug_paikdabang_zone',
          name: '빽다방 가산디지털단지역점',
          lat: 37.4800,
          lng: 126.8900,
          distanceM: 600.0,
          crowdingLevel: '여유',
          crowdingRank: 4,
          crowdingColor: 'green',
          crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          crowdingMessage: '디버깅 모드',
        ),
      ),
      // 매장3: 이디야, 혼잡도-보통
      PlaceWithZone(
        place: Place(
          id: 'debug_ediya',
          name: '이디야커피 가산점',
          address: '서울특별시 금천구 가산동',
          latitude: 37.4820,
          longitude: 126.8920,
          category: '카페',
          distanceM: 700.0,
          categoryGroupCode: 'CE7',
        ),
        zone: ZoneInfo(
          code: 'debug_ediya_zone',
          name: '이디야커피 가산점',
          lat: 37.4820,
          lng: 126.8920,
          distanceM: 700.0,
          crowdingLevel: '보통',
          crowdingRank: 3,
          crowdingColor: 'yellow',
          crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          crowdingMessage: '디버깅 모드',
        ),
      ),
    ];

    // 현재 선택된 장소가 검색 매장인지 확인
    final currentSelectedPlace = _insightData?.selected.place ?? _currentSelectedPlace!;
    final isBaseSelected = _baseSelectedPlaceWithZone != null && 
                          currentSelectedPlace.id == basePlace.id;

    final debugData = PlacesInsightResponse(
      selected: PlaceWithZone(
        place: currentSelectedPlace,
        zone: isBaseSelected ? selectedZone : (_insightData?.selected.zone ?? selectedZone),
      ),
      alternatives: recommendedPlaces,
    );

    setState(() {
      _insightData = debugData;
      _isLoading = false;
      _showLongLoadingIndicator = false;
      _showSecondLoadingMessage = false;
      _loadingStartTime = null;
      _isBottomSheetExpanded = true; // 하단 카드는 항상 펼침 상태 유지
      // 추천 리스트가 처음 표시될 때 base 스냅샷 캡처 (검색 매장만 저장)
      if (debugData.alternatives.isNotEmpty && _viewState == ViewState.baseSelectedView) {
        _baseSelectedPlaceWithZone = PlaceWithZone(
          place: basePlace,
          zone: selectedZone,
        );
        _baseRecommendations = List.from(debugData.alternatives);
      } else if (_baseSelectedPlaceWithZone != null) {
        // base 스냅샷이 이미 있으면 검색 매장의 혼잡도만 업데이트
        _baseSelectedPlaceWithZone = PlaceWithZone(
          place: _baseSelectedPlaceWithZone!.place,
          zone: selectedZone,
        );
      }
    });
  }

  /// 현재 선택된 장소 정보 (API 또는 mock 데이터)
  PlaceWithZone? get _currentPlaceWithZone {
    if (_insightData == null) return null;
    return _insightData!.selected;
  }

  /// 혼잡도 반전을 적용한 ZoneInfo
  /// 디버깅 모드에서는 선택된 혼잡도 레벨 사용 (검색 매장에만 적용)
  /// viewState에 따라 현재 선택된 장소의 zone 반환
  ZoneInfo? get _displayZone {
    if (_insightData == null) return null;
    
    // 현재 선택된 장소의 zone
    final zoneToUse = _insightData!.selected.zone;
    
    return zoneToUse;
  }

  /// 혼잡도 반전을 적용한 혼잡 여부 (약간 붐빔 또는 붐빔)
  bool get _isCongested {
    if (_insightData == null) return false;
    final zone = _displayZone ?? _insightData!.selected.zone;
    final level = zone.crowdingLevel;
    return level == '약간 붐빔' || level == '붐빔';
  }

  /// 카메라를 선택된 매장으로 이동 (padding 반영)
  /// 해결 방침 1: padding 방식 사용 시 보정 계산을 전부 제거하고 target 좌표 그대로 센터링
  Future<void> _centerToSelected(LatLng target) async {
    if (!_mapReady || _mapController == null) {
      debugPrint('[ResultMapScreen] 카메라 이동 실패: 지도가 준비되지 않음');
      return;
    }

    final c = _mapController!;
    debugPrint('[ResultMapScreen] moveCamera to: ${target.latitude}, ${target.longitude}');

    // 상단/하단 시트가 지도 위를 덮는 높이(px)
    final double topInset = 100.0; // 상단 카드 높이
    final double bottomInset = _isBottomSheetExpanded 
        ? MediaQuery.of(context).size.height * 0.6 // 펼친 상태: 화면 높이의 60%
        : 150.0; // 접힌 상태: 대략 150px

    // 혼잡도 보정: 검색 매장이 혼잡하면 extraBottomPx 추가
    final baseZone = _baseSelectedPlaceWithZone?.zone;
    final currentSelectedCrowdIsBusy = baseZone != null && 
        (baseZone.crowdingLevel == '약간 붐빔' || baseZone.crowdingLevel == '붐빔');
    final double extraBottom = currentSelectedCrowdIsBusy ? 60.0 : 0.0;

    try {
      // 카메라 이동 (target 좌표 그대로 사용)
      debugPrint('[ResultMapScreen] 원래 위치 (target): $target');
      debugPrint('[ResultMapScreen] topInset: $topInset, bottomInset: $bottomInset, extraBottom: $extraBottom');

      final cameraUpdate = CameraUpdate.newCenterPosition(target);
      await c.moveCamera(
        cameraUpdate,
        animation: const CameraAnimation(350),
      );
      
      debugPrint('[ResultMapScreen] ✅ 카메라 이동 완료 (target 좌표 그대로 사용)');
      
      // (가능하면) 카메라 위치 확인
      try {
        final pos = await c.getCameraPosition();
        debugPrint('[ResultMapScreen] camera after: ${pos.position}');
      } catch (e) {
        // getCameraPosition이 없는 경우 무시
        debugPrint('[ResultMapScreen] getCameraPosition 사용 불가: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] ❌ 카메라 이동 실패: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
    }
  }

  /// 추천 장소 선택 시 호출
  Future<void> _onRecommendedPlaceSelected(PlaceWithZone placeWithZone) async {
    if (_insightData == null) return;
    
    final place = placeWithZone.place;
    debugPrint('[ResultMapScreen] tap recommended: ${place.id}, ${place.latitude}, ${place.longitude}');
    
    // base 스냅샷이 없으면 현재 상태를 base로 저장
    if (_baseSelectedPlaceWithZone == null) {
      _baseSelectedPlaceWithZone = _insightData!.selected;
      _baseRecommendations = List.from(_insightData!.alternatives);
    }
    
    setState(() {
      // 임시 선택된 장소로 변경
      _tempSelectedPlaceWithZone = placeWithZone;
      _viewState = ViewState.tempSelectedFromRecommendation;
      
      // 현재 선택된 장소를 임시 선택된 장소로 업데이트
      // 다른 추천 매장들은 유지 (현재 선택된 매장 제외)
      final otherRecommendations = _baseRecommendations
          .where((rec) => rec.place.id != placeWithZone.place.id)
          .toList();
      
      _insightData = PlacesInsightResponse(
        selected: placeWithZone,
        alternatives: otherRecommendations, // 다른 추천 매장들 유지
      );
      _currentSelectedPlace = placeWithZone.place;
    });
    
    // 카메라 이동 호출
    await _centerToSelected(LatLng(place.latitude, place.longitude));
    
    // 추천 매장 선택 시: 이미 있는 데이터를 사용하므로 API 호출 없음
    // TIME 탭의 경우에만 선택된 추천 매장의 시간대 정보가 필요하면 로드
    // (하지만 사용자가 말하길 이미 필요한 정보는 다 있다고 함)
    // 따라서 API 호출 없이 기존 데이터만 사용
  }
  
  /// 활성 탭의 데이터 재로드
  void _reloadActiveTabData() {
    if (_selectedTab == 'time') {
      _loadRecommendTimes();
    } else if (_selectedTab == 'place') {
      // 반경 모드 초기화하지 않고 현재 모드 유지
    _loadInsight();
    }
  }

  /// 추천 시간대 데이터 로드
  Future<void> _loadRecommendTimes() async {
    if (_currentSelectedPlace == null) return;

    setState(() {
      _timeTabState = TimeTabState.loading;
      _timeTabError = null;
    });
    
    try {
      final result = await _recommendTimesRepository.getRecommendTimes(_currentSelectedPlace!.id);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<RecommendTimesResponse>():
            final recommendations = result.data.recommendations;
            // 모든 recommendations의 windows를 평탄화하여 확인
            final hasAnyWindows = recommendations.any((rec) => rec.windows.isNotEmpty);
            setState(() {
              _recommendTimesData = result.data;
              if (!hasAnyWindows) {
                _timeTabState = TimeTabState.empty;
              } else {
                _timeTabState = TimeTabState.success;
              }
            });
          case ApiFailure<RecommendTimesResponse>():
            setState(() {
              _timeTabState = TimeTabState.error;
              _timeTabError = result.message;
            });
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _timeTabState = TimeTabState.error;
          _timeTabError = e.toString();
        });
      }
    }
  }



  /// 리턴 아이콘 탭 핸들러: 원래 선택 상태로 복원
  void _handleReturnToBase() {
    if (_baseSelectedPlaceWithZone == null) return;
    
    setState(() {
      // 원래 선택된 장소로 복원
      _viewState = ViewState.baseSelectedView;
      _tempSelectedPlaceWithZone = null;
      
      // base 스냅샷으로 복원
      _insightData = PlacesInsightResponse(
        selected: _baseSelectedPlaceWithZone!,
        alternatives: List.from(_baseRecommendations),
      );
      _currentSelectedPlace = _baseSelectedPlaceWithZone!.place;
    });
    
    // 원래 선택으로 복원 시 활성 탭의 데이터 재로드하지 않음
    // 이미 스냅샷으로 복원했으므로 API 재호출 불필요
    // 지도가 다시 불러와지는 것을 방지하기 위해 _reloadActiveTabData() 호출 제거
  }

  @override
  Widget build(BuildContext context) {
    // 선택 매장: 사용자가 지금 메인으로 살펴보고 있는 매장
    // 처음엔 검색 매장이 선택 매장이고, 추천 매장 클릭 시 해당 매장이 선택 매장이 됨
    final selectedPlace = _tempSelectedPlaceWithZone?.place ?? 
                         _currentPlaceWithZone?.place ?? 
                         _currentSelectedPlace;
    
    // 검색 매장: 사용자가 검색 화면에서 선택한 매장 (baseSelectedPlaceWithZone)
    // 추천 매장: 검색 매장이 붐빌 시 추천하는 매장들 (baseRecommendations 또는 _insightData.alternatives)
    // 선택 매장: 사용자가 지금 메인으로 살펴보고 있는 매장 (selectedPlace)
    // 
    // 마커 표시 규칙:
    // - selected 마커: 선택 매장에만 사용
    // - 일반 마커: 검색 매장 + 추천 매장들 (선택 매장 제외)
    List<PlaceWithZone> allOtherPlaces = [];
    
    // 추천 매장 목록: base 스냅샷이 있으면 그것을 사용, 없으면 현재 insightData 사용
    final recommendationsToUse = _baseRecommendations.isNotEmpty 
        ? _baseRecommendations 
        : (_insightData?.alternatives ?? []);
    
    if (_baseSelectedPlaceWithZone != null) {
      final selectedPlaceId = selectedPlace?.id;
      
      // 검색 매장 추가 (선택 매장이 아닌 경우)
      if (_baseSelectedPlaceWithZone!.place.id != selectedPlaceId) {
        allOtherPlaces.add(_baseSelectedPlaceWithZone!);
      }
      
      // 추천 매장들 추가 (선택 매장이 아닌 경우)
      for (final rec in recommendationsToUse) {
        if (rec.place.id != selectedPlaceId) {
          allOtherPlaces.add(rec);
        }
      }
    } else if (_insightData != null && recommendationsToUse.isNotEmpty) {
      // base 스냅샷이 없어도 현재 insightData의 추천 매장은 표시
      final selectedPlaceId = selectedPlace?.id;
      for (final rec in recommendationsToUse) {
        if (rec.place.id != selectedPlaceId) {
          allOtherPlaces.add(rec);
        }
      }
    }
    
    // 추천 매장 마커 표시 조건:
    // 1. 검색 매장이 혼잡할 때 (약간 붐빔, 붐빔)
    // 2. 장소 바꾸기 탭이 선택되었을 때
    // 두 조건을 모두 만족해야 마커 표시
    final baseZone = _baseSelectedPlaceWithZone?.zone;
    final baseIsCongested = baseZone != null && 
                           (baseZone.crowdingLevel == '약간 붐빔' || baseZone.crowdingLevel == '붐빔');
    final isPlaceTabSelected = _selectedTab == 'place';
    
    final recommendedPlaces = (baseIsCongested && isPlaceTabSelected && allOtherPlaces.isNotEmpty) 
        ? allOtherPlaces.take(3).toList() 
        : null;
    
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼 동작을 '다시 선택'으로 처리
        Navigator.pushReplacementNamed(context, Routes.search);
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            elevation: 0,
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 지도는 전체 화면에 표시
            // API 응답이 있으면 zoneInfo 전달 (없으면 null로 회색 마커 표시)
            if (!_isLoading)
            MapView(
              selectedPlace: selectedPlace,
              zoneInfo: _displayZone,
              recommendedPlaces: recommendedPlaces,
              topCardHeight: 100.0, // 상단 카드 높이 (대략 100px)
              bottomCardHeight: _isBottomSheetExpanded 
                  ? MediaQuery.of(context).size.height * 0.6 // 펼친 상태: 화면 높이의 60%
                  : 150.0, // 접힌 상태: 선택 매장 정보 + 상태 문구 (대략 150px)
              baseZoneInfo: _baseSelectedPlaceWithZone?.zone, // 검색 매장의 혼잡도 정보 (초기 카메라 위치 조정용)
              onMapControllerReady: (controller) {
                _mapController = controller;
                _mapReady = true;
                debugPrint('[ResultMapScreen] ✅ 지도 컨트롤러 준비 완료');
                
                // 초기 진입 시 카메라 이동 (첫 프레임 이후 실행)
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final sp = selectedPlace ?? _currentSelectedPlace;
                  if (sp == null) {
                    debugPrint('[ResultMapScreen] 초기 카메라 이동 스킵: 선택된 매장이 없음');
                    return;
                  }
                  debugPrint('[ResultMapScreen] 초기 진입: 검색 매장으로 카메라 이동');
                  await _centerToSelected(LatLng(sp.latitude, sp.longitude));
                });
              },
            )
            else
              // 지도 로딩 중: 흰 화면 + 단계별 아이콘 + 문구
              _buildLoadingScreen(),
            // 3초 이상 로딩 중일 때 원형 프로그레스바 표시
            if (_showLongLoadingIndicator && !_isLoading)
              Stack(
                children: [
                  // 약간 어두운 배경
                  Container(
                    color: Colors.black.withOpacity(0.1),
                  ),
                  // 중앙 카드
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text(
                            '정보를 불러오고 있어요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
            // 상단 섹션: 항상 표시
            if (selectedPlace != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopSection(selectedPlace),
                    ],
                  ),
                ),
              ),
            // 하단 바텀시트: 항상 표시 (상태에 따라 내용 변경)
            if (_insightData != null && !_isLoading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomSheet(),
              ),
          ],
        ),
      ),
    );
  }




  /// 상단 고정 앵커: 브랜드 아이콘, [기준] 라벨 + 장소명, 다시 검색 버튼
  Widget _buildTopSection(Place selectedPlace) {
    final placeName = selectedPlace.name;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _DesignTokens.spacing20,
        vertical: _DesignTokens.spacing16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _DesignTokens.grayBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: 브랜드 아이콘 (원형, #FFD700 배경)
          _buildBrandIconWithBg(
            placeName, 
            size: 40,
            category: selectedPlace.category,
            categoryGroupCode: selectedPlace.categoryGroupCode,
          ),
          const SizedBox(width: _DesignTokens.spacing12),
          // Center: [기준] 라벨 (위) + 장소명 (아래)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // [기준] 라벨
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _DesignTokens.grayBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '기준',
                    style: TextStyle(
                      fontSize: 12,
                fontWeight: FontWeight.w600,
                      color: _DesignTokens.grayText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 장소명
                Text(
                  placeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _DesignTokens.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
              ],
          ),
          ),
          // Right: 다시 검색 버튼
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, Routes.search);
            },
            child: const Text(
              '다시 검색',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 브랜드 아이콘 with 배경 (#FFD700)
  Widget _buildBrandIconWithBg(String? placeName, {double size = 40, String? category, String? categoryGroupCode}) {
    // 브랜드명에서 에셋 경로 찾기
    final brandAssetPath = BrandIconMapper.getBrandIconAsset(placeName);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _DesignTokens.brandIconBg,
        shape: BoxShape.circle,
      ),
      child: brandAssetPath != null
          ? ClipOval(
              child: Image.asset(
                brandAssetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderIcon(size, category: category, categoryGroupCode: categoryGroupCode);
                },
              ),
            )
          : _buildPlaceholderIcon(size, category: category, categoryGroupCode: categoryGroupCode),
    );
  }


  /// 하단 바텀시트: 통일된 구조로 모든 혼잡도 상태 표시
  Widget _buildBottomSheet() {
    if (_currentPlaceWithZone == null) return const SizedBox.shrink();

    final placeWithZone = _currentPlaceWithZone!;
    final zone = _displayZone ?? placeWithZone.zone;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // 60vh
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_DesignTokens.radius16),
          topRight: Radius.circular(_DesignTokens.radius16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildUnifiedBottomSheet(placeWithZone, zone),
    );
  }

  /// 통일된 바텀시트: 매장 정보, 상태 메시지, 가이던스, 선택적 추천 리스트
  Widget _buildUnifiedBottomSheet(PlaceWithZone placeWithZone, ZoneInfo zone) {
    // 추천 매장 목록: 검색 매장이 혼잡하고 장소 바꾸기 탭 선택 시에만 표시
    final baseZone = _baseSelectedPlaceWithZone?.zone;
    final baseIsCongested = baseZone != null && 
                           (baseZone.crowdingLevel == '약간 붐빔' || baseZone.crowdingLevel == '붐빔');
    final isPlaceTabSelected = _selectedTab == 'place';
    
    final recommendedPlaces = (baseIsCongested && isPlaceTabSelected && _insightData != null)
        ? _insightData!.alternatives.take(3).toList()
        : <PlaceWithZone>[];
    
    final isCrowded = zone.crowdingLevel == '약간 붐빔' || zone.crowdingLevel == '붐빔';
    final showReturnIcon = _viewState == ViewState.tempSelectedFromRecommendation;

    return SingleChildScrollView(
      controller: _bottomSheetScrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _DesignTokens.spacing20,
          _DesignTokens.spacing24,
          _DesignTokens.spacing20,
          _DesignTokens.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. 리턴 아이콘 (임시 선택 상태일 때만 표시)
          if (showReturnIcon) ...[
            Padding(
                padding: const EdgeInsets.only(bottom: _DesignTokens.spacing8),
              child: _buildReturnIcon(),
            ),
          ],
          
            // Section 1: Header - 원형 아이콘 48px, storeName, badge + 접기/펼치기 버튼
            Row(
              children: [
                Expanded(
                  child: _buildBottomSheetHeader(placeWithZone.place, zone),
                ),
                // 접기/펼치기 버튼 (혼잡할 때만 표시)
                if (isCrowded)
                  IconButton(
                    icon: Icon(
                      _isBottomSheetExpanded ? Icons.expand_more : Icons.expand_less,
                      color: _DesignTokens.grayText,
                    ),
                    onPressed: () {
                      setState(() {
                        _isBottomSheetExpanded = !_isBottomSheetExpanded;
                      });
                    },
                  ),
              ],
            ),
            
            // Section 2: Status text - "지금은 {혼잡도} 편이에요" (항상 표시)
          Padding(
              padding: const EdgeInsets.only(top: _DesignTokens.spacing16),
              child: _buildStatusText(zone.crowdingLevel),
            ),
            
            // 펼친 상태일 때만 탭과 탭 콘텐츠 표시
            if (_isBottomSheetExpanded && isCrowded) ...[
              // Section 3: Segmented control tabs (혼잡할 때만 표시)
            Padding(
                padding: const EdgeInsets.only(top: _DesignTokens.spacing20),
                child: _buildSegmentedControl(
                  selectedTab: _selectedTab,
                  onTabChanged: _onTabChanged,
                ),
              ),
              
              // Section 4: Tab content (혼잡할 때만 표시, marginTop: 24px)
            Padding(
                padding: const EdgeInsets.only(top: _DesignTokens.spacing24),
                child: _buildTabContent(
                  selectedTab: _selectedTab,
                  placeWithZone: placeWithZone,
                  zone: zone,
                  recommendedPlaces: recommendedPlaces,
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  /// Section 1: Bottom sheet header - 원형 아이콘 48px, storeName, badge
  Widget _buildBottomSheetHeader(Place place, ZoneInfo zone) {
    return Row(
      children: [
        // 원형 아이콘 48px
        _buildBrandIconWithBg(
          place.name, 
          size: 48,
          category: place.category,
          categoryGroupCode: place.categoryGroupCode,
        ),
        const SizedBox(width: _DesignTokens.spacing12),
        // storeName (18px, fontWeight 700)
        Expanded(
          child: Text(
            place.name,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _DesignTokens.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: _DesignTokens.spacing12),
        // Badge - API에서 받은 혼잡도
        _buildCrowdingBadge(zone.crowdingLevel),
      ],
    );
  }
  
  /// 혼잡도 배지
  Widget _buildCrowdingBadge(String crowdingLevel) {
    final badgeConfig = _DesignTokens.badgeColors[crowdingLevel] ?? 
        _DesignTokens.badgeColors['여유']!;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _DesignTokens.spacing14,
        vertical: _DesignTokens.spacing6,
      ),
      decoration: BoxDecoration(
        color: badgeConfig['bg'],
        borderRadius: BorderRadius.circular(_DesignTokens.radius16),
      ),
      child: Text(
        crowdingLevel.isNotEmpty ? crowdingLevel : '여유',
              style: TextStyle(
          fontSize: 13,
          color: badgeConfig['text'],
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  
  /// Section 2: Status text - 혼잡도별 완성된 문장 사용
  Widget _buildStatusText(String crowdingLevel) {
    // 혼잡도별 완성된 문장 매핑
    final statusTextByCongestion = {
      '여유': '지금은 여유 있어요',
      '원활': '지금은 여유 있어요',
      '보통': '지금은 사람이 조금 있는 편이에요',
      '약간 붐빔': '지금은 약간 붐비는 편이에요',
      '붐빔': '지금은 붐비고 있어요',
    };
    
    final statusText = statusTextByCongestion[crowdingLevel] ?? 
                      statusTextByCongestion['여유']!;
    
    return Text(
      statusText,
      style: const TextStyle(
        fontSize: 14,
        color: _DesignTokens.grayText,
      ),
    );
  }
  
  /// Section 3: Segmented control tabs
  Widget _buildSegmentedControl({
    required String selectedTab,
    required Function(String) onTabChanged,
  }) {
    return Container(
      width: double.infinity,
      height: 48, // 높이를 44에서 48로 증가하여 텍스트가 잘리지 않도록
      decoration: BoxDecoration(
        color: _DesignTokens.grayBg,
        borderRadius: BorderRadius.circular(_DesignTokens.radius12),
      ),
      padding: const EdgeInsets.all(_DesignTokens.spacing4),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentedTab(
              label: '시간 바꾸기',
              isSelected: selectedTab == 'time',
              onTap: () => onTabChanged('time'),
            ),
          ),
          Expanded(
            child: _buildSegmentedTab(
              label: '장소 바꾸기',
              isSelected: selectedTab == 'place',
              onTap: () => onTabChanged('place'),
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented control tab item
  Widget _buildSegmentedTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(_DesignTokens.radius8),
            boxShadow: isSelected
                ? [
            BoxShadow(
                      color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), // vertical을 12에서 10으로 줄이고 horizontal 추가
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? _DesignTokens.black : _DesignTokens.grayText,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible, // 텍스트가 잘리지 않도록
          ),
        ),
      ),
    );
  }

  /// Tab content builder - switches between time and place tabs
  Widget _buildTabContent({
    required String selectedTab,
    required PlaceWithZone placeWithZone,
    required ZoneInfo zone,
    required List<PlaceWithZone> recommendedPlaces,
  }) {
    if (selectedTab == 'time') {
      return _buildTimeTabContent(zone);
    } else {
      // PLACE 탭: 상태에 따라 recommendedPlaces 사용 여부 결정
      final placesToShow = _placeTabState == PlaceTabState.success ? recommendedPlaces : <PlaceWithZone>[];
      return _buildPlaceTabContent(zone, placesToShow);
    }
  }
  
  /// Time tab content
  Widget _buildTimeTabContent(ZoneInfo zone) {
    switch (_timeTabState) {
      case TimeTabState.loading:
        return _buildTimeTabLoading();
      case TimeTabState.success:
        return _buildTimeTabSuccess();
      case TimeTabState.empty:
        return _buildTimeTabEmpty();
      case TimeTabState.error:
        return _buildTimeTabError();
    }
  }
  
  /// TIME 탭 로딩 상태
  Widget _buildTimeTabLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이때 오면 여유로워요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        // 스켈레톤 (3개)
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: _DesignTokens.spacing12),
      child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: _DesignTokens.spacing12),
              Expanded(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: _DesignTokens.spacing12),
              SizedBox(
                width: 80,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  /// TIME 탭 성공 상태
  Widget _buildTimeTabSuccess() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          '이때 오면 여유로워요',
            style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        ..._buildTimeList(),
        const SizedBox(height: _DesignTokens.spacing16),
        const Text(
          '요즘 이 시간대가 쾌적해요',
          style: TextStyle(
            fontSize: 13,
            color: _DesignTokens.grayText,
            ),
          ),
        ],
    );
  }
  
  /// TIME 탭 빈 상태
  Widget _buildTimeTabEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이때 오면 여유로워요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing24),
        _buildEmptyState(
          title: '아직 이 장소의 시간대 정보가 부족해요',
          body: '조금만 기다려주시면 더 정확한 정보를 알려드릴게요',
        ),
      ],
    );
  }

  /// TIME 탭 에러 상태
  Widget _buildTimeTabError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이때 오면 여유로워요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing24),
        _buildErrorState(
          title: '시간 정보를 불러오지 못했어요',
          body: '잠시 후 다시 시도해 주세요',
          onRetry: _retryTime,
        ),
      ],
    );
  }
  
  /// Build time list cards
  List<Widget> _buildTimeList() {
    if (_recommendTimesData == null) return [];
    
    final now = DateTime.now();
    final today = now.weekday - 1; // 0 = Monday, 6 = Sunday
    
    final List<Widget> widgets = [];
    
    // Get all time windows from recommendations, sorted by day
    final List<({int day, String dayName, TimeWindow window})> timeWindows = [];
    
    for (final dayRec in _recommendTimesData!.recommendations) {
      for (final window in dayRec.windows) {
        timeWindows.add((day: dayRec.dow, dayName: dayRec.dowName, window: window));
      }
    }
    
    // Sort by day (today first, then next days)
    timeWindows.sort((a, b) {
      final aDay = (a.day - today + 7) % 7;
      final bDay = (b.day - today + 7) % 7;
      if (aDay != bDay) return aDay.compareTo(bDay);
      return a.window.startHour.compareTo(b.window.startHour);
    });
    
    // Take first 5 recommendations
    for (final item in timeWindows.take(5)) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: _DesignTokens.spacing12),
          child: _buildTimeCard(item.dayName, item.window, now),
        ),
      );
    }
    
    return widgets;
  }
  
  /// Build time card
  Widget _buildTimeCard(String dayName, TimeWindow window, DateTime now) {
    final startTime = '${window.startHour.toString().padLeft(2, '0')}:00';
    final endTime = '${window.endHour.toString().padLeft(2, '0')}:00';
    final timeRange = '$startTime-$endTime';
    final relativeTime = _calculateRelativeTime(window, now);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Day (60px width)
        SizedBox(
          width: 60,
          child: Text(
            dayName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _DesignTokens.black,
            ),
          ),
        ),
        const SizedBox(width: _DesignTokens.spacing12),
        // Time range (flex: 1)
        Expanded(
          child: Text(
            timeRange,
            style: const TextStyle(
              fontSize: 15,
              color: _DesignTokens.black,
            ),
          ),
        ),
        // Relative time
        Text(
          relativeTime,
            style: const TextStyle(
              fontSize: 14,
            color: _DesignTokens.grayText,
          ),
        ),
      ],
    );
  }
  
  /// Calculate relative time string
  String _calculateRelativeTime(TimeWindow window, DateTime now) {
    final today = now.weekday - 1; // 0 = Monday, 6 = Sunday
    final windowDay = window.dow;
    
    // Calculate days difference (0 = today, 1 = tomorrow, etc.)
    int daysDiff = (windowDay - today + 7) % 7;
    
    // If it's today but the time has passed, it's next week
    if (daysDiff == 0 && window.startHour < now.hour) {
      daysDiff = 7; // Next week
    }
    
    if (daysDiff == 0) {
      // Today
      final hoursDiff = window.startHour - now.hour;
      if (hoursDiff <= 0) {
        return '🕒 지금';
      } else {
        return '🕒 $hoursDiff시간 후';
      }
    } else if (daysDiff == 1) {
      // Tomorrow
      final hour = window.startHour;
      if (hour < 12) {
        return '☀️ 내일 오전';
      } else {
        return '☀️ 내일 오후';
      }
    } else if (daysDiff == 2) {
      // Day after tomorrow
      return '🌤️ 모레';
    } else {
      // More than 2 days
      return '${window.dowName}요일';
    }
  }
  
  /// Place tab content
  Widget _buildPlaceTabContent(ZoneInfo zone, List<PlaceWithZone> recommendedPlaces) {
    switch (_placeTabState) {
      case PlaceTabState.loading:
        return _buildPlaceTabLoading(zone);
      case PlaceTabState.success:
        return _buildPlaceTabSuccess(zone, recommendedPlaces);
      case PlaceTabState.emptyFirst:
        return _buildPlaceTabEmptyFirst(zone);
      case PlaceTabState.emptyExpanded:
        return _buildPlaceTabEmptyExpanded(zone);
      case PlaceTabState.error:
        return _buildPlaceTabError(zone);
    }
  }
  
  /// PLACE 탭 헤더 텍스트 결정
  String _getPlaceTabHeaderText(ZoneInfo zone) {
    return zone.crowdingLevel == '붐빔'
        ? '지금 이용하기 좋은 곳이 있어요'
        : '근처에 여유로운 곳이 있어요';
  }
  
  /// PLACE 탭 로딩 상태
  Widget _buildPlaceTabLoading(ZoneInfo zone) {
    final headerText = _getPlaceTabHeaderText(zone);
    
    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
          headerText,
                  style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        // 스켈레톤 (3개)
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: _DesignTokens.spacing12),
          child: Row(
                  children: [
        Container(
                width: 44,
                height: 44,
          decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: _DesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: _DesignTokens.spacing12),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        )),
      ],
    );
  }

  /// PLACE 탭 성공 상태
  Widget _buildPlaceTabSuccess(ZoneInfo zone, List<PlaceWithZone> recommendedPlaces) {
    final headerText = _getPlaceTabHeaderText(zone);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        ...recommendedPlaces.map((placeWithZone) {
          return Padding(
            padding: const EdgeInsets.only(bottom: _DesignTokens.spacing12),
            child: _buildPlaceCard(placeWithZone),
          );
        }).toList(),
      ],
    );
  }
  
  /// PLACE 탭 첫 번째 빈 상태 (기본 반경)
  Widget _buildPlaceTabEmptyFirst(ZoneInfo zone) {
    // 선택적 힌트: 혼잡도 분산이 낮을 때만 표시
    final showTimeHint = _shouldShowTimeHint();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          '지금은 약간 붐비는 편이에요',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        // Description
        const Text(
          '주변 1km 내 카페는 혼잡도가 비슷해요',
          style: TextStyle(
            fontSize: 14,
            color: _DesignTokens.grayText,
          ),
        ),
        // Optional hint
        if (showTimeHint) ...[
          const SizedBox(height: 12),
          const Text(
            '지금은 시간대를 바꾸는 것이 더 효과적일 수 있어요',
            style: TextStyle(
              fontSize: 13,
              color: _DesignTokens.grayTextTertiary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Action buttons
        _buildActionButton(
          label: '시간 바꾸기',
          subLabel: '더 여유로운 시간대를 추천해드릴게요',
          onPressed: _isLoadingExpand ? null : _openTimeRecommendation,
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: '범위 넓혀서 찾기',
          subLabel: '주변 2km까지 확대됩니다',
          onPressed: _isLoadingExpand ? null : _expandRadiusAndRefetch,
          isPrimary: false,
          isLoading: _isLoadingExpand,
        ),
      ],
    );
  }
  
  /// PLACE 탭 확장 후 빈 상태
  Widget _buildPlaceTabEmptyExpanded(ZoneInfo zone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          '지금은 약간 붐비는 편이에요',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        // Description (확장 후에는 미세 강화)
        const Text(
          '주변 2km 내에서도 혼잡도가 비슷해요',
          style: TextStyle(
            fontSize: 14,
            color: _DesignTokens.grayText,
          ),
        ),
        const SizedBox(height: 20),
        // Action buttons
        _buildActionButton(
          label: '시간 바꾸기',
          subLabel: '더 여유로운 시간대를 추천해드릴게요',
          onPressed: _isLoadingExpand ? null : _openTimeRecommendation,
          isPrimary: true,
        ),
      ],
    );
  }
  
  /// 선택적 힌트 표시 여부 결정 (혼잡도 분산 기반)
  bool _shouldShowTimeHint() {
    // TODO: 혼잡도 분산 계산 로직 구현
    // 현재는 간단히 항상 false로 설정 (나중에 구현)
    // 탐색 반경 내 후보들의 혼잡도 점수 표준편차가 임계값 이하일 때만 true
    return false;
  }
  
  /// 액션 버튼 빌더 (라벨 + 보조 텍스트)
  Widget _buildActionButton({
    required String label,
    required String subLabel,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    if (isPrimary) {
      // 시간 바꾸기: 중성 배경 버튼 (연한 회색/웜 화이트 배경, 다크 그레이 텍스트)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0EBEB), // R240 G235 B235
              foregroundColor: const Color(0xFF1A1A1A), // 거의 블랙에 가까운 다크 그레이
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            subLabel,
            style: const TextStyle(
              fontSize: 12,
              color: _DesignTokens.grayTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      // 범위 넓혀서 찾기: 배경 없는 텍스트 버튼 (더 차분하게)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A), // 다크 그레이
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // 시간 바꾸기보다 작게
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14, // 시간 바꾸기보다 작게
                      fontWeight: FontWeight.w500, // 시간 바꾸기보다 약하게
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: const TextStyle(
              fontSize: 12,
              color: _DesignTokens.grayTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }
  
  /// PLACE 탭 에러 상태
  Widget _buildPlaceTabError(ZoneInfo zone) {
    return _buildErrorState(
      title: '근처 장소 정보를 불러오지 못했어요',
      body: '잠시 후 다시 시도해 주세요',
      onRetry: _retryPlace,
      centerAlign: true,
    );
  }
  
  /// 빈 상태 공통 UI
  Widget _buildEmptyState({
    required String title,
    required String body,
    Widget? actionButton,
    bool centerAlign = false,
  }) {
    final content = Column(
      crossAxisAlignment: centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: centerAlign ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centerAlign ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: centerAlign ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 14,
            color: _DesignTokens.grayText,
          ),
        ),
        if (actionButton != null) ...[
          const SizedBox(height: 16),
          actionButton,
        ],
      ],
    );

    // 중앙 정렬일 때 전체 너비를 사용하도록 SizedBox로 감싸기
    if (centerAlign) {
      return SizedBox(
        width: double.infinity,
        child: content,
      );
    }

    return content;
  }
  
  /// 에러 상태 공통 UI
  Widget _buildErrorState({
    required String title,
    required String body,
    required VoidCallback onRetry,
    bool centerAlign = false,
  }) {
    final content = Column(
      crossAxisAlignment: centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: centerAlign ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centerAlign ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: centerAlign ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 14,
            color: _DesignTokens.grayText,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: _DesignTokens.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('다시 시도'),
        ),
      ],
    );

    // 중앙 정렬일 때 전체 너비를 사용하도록 SizedBox로 감싸기
    if (centerAlign) {
      return SizedBox(
        width: double.infinity,
        child: content,
      );
    }

    return content;
  }
  
  /// Build place card
  Widget _buildPlaceCard(PlaceWithZone placeWithZone) {
    final place = placeWithZone.place;
    final zone = placeWithZone.zone;
    final distanceText = _formatDistance(place.distanceM);

    return InkWell(
      onTap: () => _onRecommendedPlaceSelected(placeWithZone),
      borderRadius: BorderRadius.circular(_DesignTokens.radius12),
      child: Container(
        padding: const EdgeInsets.all(_DesignTokens.spacing16),
        decoration: BoxDecoration(
          color: _DesignTokens.grayBg,
          borderRadius: BorderRadius.circular(_DesignTokens.radius12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon (44px 원형)
            _buildBrandIcon(
              place.name, 
              size: 44,
              category: place.category,
              categoryGroupCode: place.categoryGroupCode,
            ),
            const SizedBox(width: _DesignTokens.spacing12),
            // Text container (flex: 1)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _DesignTokens.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Info (congestionLevel • distance)
                        Text(
                    '${zone.crowdingLevel} • $distanceText',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _DesignTokens.grayText,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            const Icon(
              Icons.chevron_right,
              color: _DesignTokens.grayText,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Format distance with walking time calculation
  String _formatDistance(double distanceM) {
    if (distanceM <= 10) {
      return '바로 옆';
    }
    
    // Walking speed: 80m/min
    final minutes = (distanceM / 80).ceil();
    
    if (minutes <= 5) {
      return '걸어서 ${minutes}분';
    }
    
    return '${distanceM.toStringAsFixed(0)}m';
  }
  
  /// 리턴 아이콘 (임시 선택 상태에서 원래 선택으로 돌아가기)
  Widget _buildReturnIcon() {
    return InkWell(
      onTap: _handleReturnToBase,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
            const Icon(
              Icons.chevron_left,
              color: Colors.black87,
              size: 20,
            ),
                            const SizedBox(width: 4),
            const Text(
              '목록으로 돌아가기',
                              style: TextStyle(
                                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 브랜드 아이콘 빌더 (원형)
  /// 브랜드명을 기반으로 에셋 이미지 사용
  Widget _buildBrandIcon(String? placeName, {double size = 48, String? category, String? categoryGroupCode}) {
    // 브랜드명에서 에셋 경로 찾기
    final brandAssetPath = BrandIconMapper.getBrandIconAsset(placeName);
    
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[200], // placeholder 배경색
        child: brandAssetPath != null
            ? Image.asset(
                brandAssetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high, // 고화질 필터링
                errorBuilder: (context, error, stackTrace) {
                  // 에셋 로딩 실패 시 placeholder 표시
                  return _buildPlaceholderIcon(size, category: category, categoryGroupCode: categoryGroupCode);
                },
              )
            : _buildPlaceholderIcon(size, category: category, categoryGroupCode: categoryGroupCode),
      ),
    );
  }

  /// 로딩 화면 빌더 (단계별 메시지와 아이콘 표시)
  Widget _buildLoadingScreen() {
    final message = _showSecondLoadingMessage
        ? '주변 매장의 혼잡도를 계산하고 있어요'
        : '주변 매장 정보를 불러오고 있어요';
    
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _showSecondLoadingMessage
                ? SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[400]!.withOpacity(0.9),
                      ),
                    ),
                  )
                : Icon(
                    Icons.location_on,
                    size: 56,
                    color: Colors.grey[400]?.withOpacity(0.9),
                  ),
            const SizedBox(height: 18),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder 아이콘 (카테고리에 따라 다른 이미지 사용)
  Widget _buildPlaceholderIcon(double size, {String? category, String? categoryGroupCode}) {
    // 카테고리 판단: 카페인지 음식점인지 확인
    final isCafe = categoryGroupCode == 'CE7' || 
                   (category != null && (category.contains('카페') || category.contains('커피')));
    final isRestaurant = categoryGroupCode == 'FD6' || 
                        (category != null && (category.contains('음식') || category.contains('식당')));
    
    String placeholderAsset;
    if (isCafe) {
      placeholderAsset = 'assets/brands/placeholder_cafe.png';
    } else if (isRestaurant) {
      placeholderAsset = 'assets/brands/placeholder_meal.png';
    } else {
      // 기본값: 카페로 처리
      placeholderAsset = 'assets/brands/placeholder_cafe.png';
    }
    
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: Image.asset(
          placeholderAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // placeholder 이미지도 로딩 실패 시 기본 아이콘 표시
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(
        Icons.store,
        size: size * 0.5,
        color: Colors.grey[400],
              ),
            );
          },
        ),
      ),
    );
  }
}
