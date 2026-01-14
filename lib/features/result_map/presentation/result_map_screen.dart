import 'package:flutter/material.dart';

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
import '../widgets/map_view.dart';

/// Design tokens for the result map screen
class _DesignTokens {
  // Colors
  static const Color primary = Color(0xFF007AFF);
  static const Color warning = Color(0xFFFF6B35);
  static const Color success = Color(0xFF2E7D32);
  static const Color grayBg = Color(0xFFF9F9F9);
  static const Color grayBorder = Color(0xFFE0E0E0);
  static const Color grayText = Color(0xFF666666);
  static const Color black = Color(0xFF1A1A1A);
  static const Color brandIconBg = Color(0xFFFFD700); // #FFD700
  
  // Badge colors
  static const Map<String, Map<String, Color>> badgeColors = {
    '여유': {'bg': Color(0xFFE8F5E9), 'text': Color(0xFF2E7D32)},
    '보통': {'bg': Color(0xFFFFFCDD), 'text': Color(0xFFF7BB09)}, // 배경색 0xFFFFFEF5와 0xFFFFF9C4의 중간, 글씨 r247 g187 b9
    '약간 붐빔': {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFFF6B35)},
    '붐빔': {'bg': Color(0xFFFFEBEE), 'text': Color(0xFFD32F2F)},
  };
  
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
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

  PlacesInsightResponse? _insightData;
  bool _isLoading = false;
  bool _showLongLoadingIndicator = false; // 3초 이상 로딩 시 원형 프로그레스바 표시
  bool _isDebugMode = false; // 디버깅 모드 여부
  String _selectedCrowdingLevel = '붐빔'; // 선택된 혼잡도 레벨 (디버깅용)
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
  
  // 임시 선택 상태 관리
  ViewState _viewState = ViewState.baseSelectedView;
  PlaceWithZone? _baseSelectedPlaceWithZone; // 원래 선택된 장소 (스냅샷)
  List<PlaceWithZone> _baseRecommendations = []; // 원래 추천 리스트 (스냅샷)
  PlaceWithZone? _tempSelectedPlaceWithZone; // 임시 선택된 장소
  
  // 하단 카드 접기/펼치기 상태 (기본값: 펼침)
  bool _isBottomSheetExpanded = true;

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
      final radius = _placeRadiusMode == RadiusMode.expanded ? 1000 : 500;
      final request = PlacesInsightRequest(
        selected: _currentSelectedPlace!,
        userLat: location.latitude,
        userLng: location.longitude,
        radiusM: radius,
        maxAlternatives: 3,
      );

      debugPrint('[ResultMapScreen] 인사이트 데이터 로딩 시작... (반경: ${radius}m)');
      final result = await _insightRepository.getInsight(request);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<PlacesInsightResponse>():
            final isCongested = result.data.selected.zone.isCongested;
            final alternatives = result.data.alternatives;
            debugPrint('[ResultMapScreen] ✅ 데이터 로드 성공!');
            debugPrint('[ResultMapScreen] - selected: ${result.data.selected.place.name}');
            debugPrint('[ResultMapScreen] - alternatives: ${alternatives.length}개');
            debugPrint('[ResultMapScreen] - isCongested: $isCongested');
            debugPrint('[ResultMapScreen] - zone: ${result.data.selected.zone.crowdingLevel}');
            
            setState(() {
              _insightData = result.data;
              _isLoading = false;
              _showLongLoadingIndicator = false;
              _isDebugMode = false; // 실제 API 모드
              _selectedCrowdingLevel = result.data.selected.zone.crowdingLevel; // 실제 혼잡도로 초기화
              
              // PLACE 탭 상태 업데이트
              if (_selectedTab == 'place') {
                if (alternatives.isEmpty) {
                  if (_placeRadiusMode == RadiusMode.base) {
                    _placeTabState = PlaceTabState.emptyFirst;
                  } else {
                    _placeTabState = PlaceTabState.emptyExpanded;
                  }
                } else {
                  _placeTabState = PlaceTabState.success;
                }
              }
              
              // 검색 매장과 추천 매장 스냅샷 캡처 (한 번만, API 성공 시)
              if (_baseSelectedPlaceWithZone == null) {
                _baseSelectedPlaceWithZone = result.data.selected;
                _baseRecommendations = List.from(alternatives);
                debugPrint('[ResultMapScreen] ✅ 검색 매장 및 추천 매장 스냅샷 캡처 완료');
                debugPrint('[ResultMapScreen] - 검색 매장: ${_baseSelectedPlaceWithZone!.place.name}');
                debugPrint('[ResultMapScreen] - 추천 매장: ${_baseRecommendations.length}개');
              }
            });
            debugPrint('[ResultMapScreen] setState 완료: _insightData=${_insightData != null}');
            // 혼잡 상태가 변경되면 애니메이션 재시작
            if (isCongested) {
              _animationController.forward();
            } else {
              _animationController.reset();
            }
          case ApiFailure<PlacesInsightResponse>():
            debugPrint('[ResultMapScreen] 데이터 로드 실패: ${result.message}');
            if (_selectedTab == 'place') {
              setState(() {
                _placeTabState = PlaceTabState.error;
                _placeTabError = result.message;
              });
            } else {
              debugPrint('[ResultMapScreen] 디버깅 모드로 전환');
              // API 실패 시 디버깅 모드로 전환 (초기 로드 시에만)
              _loadDebugModeData();
            }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 예외 발생: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        if (_selectedTab == 'place') {
          setState(() {
            _placeTabState = PlaceTabState.error;
            _placeTabError = e.toString();
          });
        } else {
          debugPrint('[ResultMapScreen] 디버깅 모드로 전환');
          // 예외 발생 시 디버깅 모드로 전환 (초기 로드 시에만)
          _loadDebugModeData();
        }
      }
    }
  }
  
  /// 반경 확장 및 재조회
  Future<void> _expandRadiusAndRefetch() async {
    setState(() {
      _placeRadiusMode = RadiusMode.expanded;
      _placeTabState = PlaceTabState.loading;
      _placeTabError = null;
    });
    await _loadInsight();
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

    debugPrint('[ResultMapScreen] 디버깅 모드 데이터 생성 중...');
    
    // 검색 매장: base 스냅샷이 있으면 사용, 없으면 현재 선택된 장소 사용
    final basePlace = _baseSelectedPlaceWithZone?.place ?? _currentSelectedPlace!;
    final baseZone = _baseSelectedPlaceWithZone?.zone ?? ZoneInfo(
      code: 'debug_selected',
      name: basePlace.name,
      lat: basePlace.latitude,
      lng: basePlace.longitude,
      distanceM: basePlace.distanceM,
      crowdingLevel: _selectedCrowdingLevel,
      crowdingRank: _selectedCrowdingLevel == '붐빔' ? 1 : 
                    _selectedCrowdingLevel == '약간 붐빔' ? 2 :
                    _selectedCrowdingLevel == '보통' ? 3 : 4,
      crowdingColor: _selectedCrowdingLevel == '붐빔' ? 'red' :
                     _selectedCrowdingLevel == '약간 붐빔' ? 'orange' :
                     _selectedCrowdingLevel == '보통' ? 'yellow' : 'green',
      crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      crowdingMessage: '디버깅 모드',
    );
    
    // 검색 매장의 혼잡도만 업데이트
    final selectedZone = baseZone.copyWithCrowdingLevel(_selectedCrowdingLevel);

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
      _isDebugMode = true;
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

    debugPrint('[ResultMapScreen] ✅ 디버깅 모드 데이터 생성 완료');
    debugPrint('[ResultMapScreen] - 검색 매장: ${basePlace.name}, 혼잡도: $_selectedCrowdingLevel');
    debugPrint('[ResultMapScreen] - alternatives: ${recommendedPlaces.length}개');
  }

  /// 혼잡도 레벨 변경 (디버깅용) - 검색 매장에만 적용
  void _onCrowdingLevelChanged(String newLevel) {
    setState(() {
      _selectedCrowdingLevel = newLevel;
      _isBottomSheetExpanded = true; // 하단 카드는 항상 펼침 상태 유지
    });
    
    // 검색 매장이 없으면 처리하지 않음
    if (_baseSelectedPlaceWithZone == null && _insightData == null) return;
    
    // 붐빔이나 약간 붐빔으로 변경된 경우 추천 매장 API 호출
    final isCrowded = newLevel == '붐빔' || newLevel == '약간 붐빔';
    
    if (isCrowded && _currentSelectedPlace != null) {
      // 실제 API를 호출하여 추천 매장 가져오기
      debugPrint('[ResultMapScreen] 디버그: 혼잡도가 붐빔/약간 붐빔으로 변경됨, 추천 매장 API 호출');
      _loadInsightForDebugMode();
    } else if (_isDebugMode && _insightData != null) {
      // 디버깅 모드이고 혼잡하지 않은 경우 mock 데이터 사용
      _loadDebugModeData();
    } else if (_insightData != null) {
      // 실제 API 모드인 경우: 검색 매장의 혼잡도만 업데이트
      final baseZone = _baseSelectedPlaceWithZone?.zone ?? _insightData!.selected.zone;
      final updatedBaseZone = baseZone.copyWithCrowdingLevel(newLevel);
      
      // base 스냅샷 업데이트
      if (_baseSelectedPlaceWithZone != null) {
        _baseSelectedPlaceWithZone = PlaceWithZone(
          place: _baseSelectedPlaceWithZone!.place,
          zone: updatedBaseZone,
        );
      }
      
      // 현재 선택된 장소가 검색 매장인 경우에만 혼잡도 업데이트
      final isBaseSelected = _baseSelectedPlaceWithZone != null && 
                            _insightData!.selected.place.id == _baseSelectedPlaceWithZone!.place.id;
      
      setState(() {
        _insightData = PlacesInsightResponse(
          selected: PlaceWithZone(
            place: _insightData!.selected.place,
            zone: isBaseSelected ? updatedBaseZone : _insightData!.selected.zone,
          ),
          alternatives: _insightData!.alternatives,
        );
      });
    }
  }
  
  /// 디버그 모드용 추천 매장 API 호출 (혼잡도 변경 시)
  Future<void> _loadInsightForDebugMode() async {
    if (_currentSelectedPlace == null) return;

    setState(() {
      _isLoading = true;
      _showLongLoadingIndicator = false;
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
      final radius = _placeRadiusMode == RadiusMode.expanded ? 1000 : 500;
      final request = PlacesInsightRequest(
        selected: _currentSelectedPlace!,
        userLat: location.latitude,
        userLng: location.longitude,
        radiusM: radius,
        maxAlternatives: 3,
      );

      debugPrint('[ResultMapScreen] 디버그 모드: 추천 매장 API 호출 (반경: ${radius}m)');
      final result = await _insightRepository.getInsight(request);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<PlacesInsightResponse>():
            final alternatives = result.data.alternatives;
            debugPrint('[ResultMapScreen] ✅ 디버그 모드: 추천 매장 API 성공!');
            debugPrint('[ResultMapScreen] - alternatives: ${alternatives.length}개');
            
            // 검색 매장의 혼잡도만 업데이트 (추천 매장의 혼잡도는 변경하지 않음)
            final baseZone = _baseSelectedPlaceWithZone?.zone ?? result.data.selected.zone;
            final updatedBaseZone = baseZone.copyWithCrowdingLevel(_selectedCrowdingLevel);
            
            // 현재 선택된 장소가 검색 매장인지 확인
            final isBaseSelected = _baseSelectedPlaceWithZone != null && 
                                  result.data.selected.place.id == _baseSelectedPlaceWithZone!.place.id;
            
            setState(() {
              _insightData = PlacesInsightResponse(
                selected: PlaceWithZone(
                  place: result.data.selected.place,
                  zone: isBaseSelected ? updatedBaseZone : result.data.selected.zone,
                ),
                alternatives: alternatives, // 추천 매장의 혼잡도는 API 결과 그대로 사용
              );
              _isLoading = false;
              _showLongLoadingIndicator = false;
              _isDebugMode = true; // 디버그 모드 유지
              _isBottomSheetExpanded = true; // 하단 카드는 항상 펼침 상태 유지
              
              // PLACE 탭 상태 업데이트
              if (_selectedTab == 'place') {
                if (alternatives.isEmpty) {
                  if (_placeRadiusMode == RadiusMode.base) {
                    _placeTabState = PlaceTabState.emptyFirst;
                  } else {
                    _placeTabState = PlaceTabState.emptyExpanded;
                  }
                } else {
                  _placeTabState = PlaceTabState.success;
                }
              }
              
              // base 스냅샷 업데이트 (검색 매장의 혼잡도만 업데이트)
              if (_baseSelectedPlaceWithZone == null) {
                _baseSelectedPlaceWithZone = PlaceWithZone(
                  place: result.data.selected.place,
                  zone: updatedBaseZone,
                );
                _baseRecommendations = List.from(alternatives);
              } else {
                // base 스냅샷의 zone만 업데이트 (추천 매장은 API 결과 사용)
                _baseSelectedPlaceWithZone = PlaceWithZone(
                  place: _baseSelectedPlaceWithZone!.place,
                  zone: updatedBaseZone,
                );
                _baseRecommendations = List.from(alternatives);
              }
            });
            
            // 혼잡 상태이면 애니메이션 재시작
            if (_selectedCrowdingLevel == '붐빔' || _selectedCrowdingLevel == '약간 붐빔') {
              _animationController.forward();
            } else {
              _animationController.reset();
            }
          case ApiFailure<PlacesInsightResponse>():
            debugPrint('[ResultMapScreen] 디버그 모드: 추천 매장 API 실패: ${result.message}');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _showLongLoadingIndicator = false;
              });
              // API 실패 시 mock 데이터 사용
              _loadDebugModeData();
            }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 디버그 모드: 추천 매장 API 예외: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showLongLoadingIndicator = false;
        });
        // 예외 발생 시 mock 데이터 사용
        _loadDebugModeData();
      }
    }
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
    
    // 디버깅 모드이고 현재 선택된 장소가 검색 매장인 경우에만 혼잡도 업데이트
    final isBaseSelected = _baseSelectedPlaceWithZone != null && 
                          _insightData!.selected.place.id == _baseSelectedPlaceWithZone!.place.id;
    
    if (_isDebugMode && isBaseSelected && zoneToUse.crowdingLevel != _selectedCrowdingLevel) {
      return zoneToUse.copyWithCrowdingLevel(_selectedCrowdingLevel);
    }
    
    return zoneToUse;
  }

  /// 혼잡도 반전을 적용한 혼잡 여부 (약간 붐빔 또는 붐빔)
  bool get _isCongested {
    if (_insightData == null) return false;
    final zone = _displayZone ?? _insightData!.selected.zone;
    final level = zone.crowdingLevel;
    return level == '약간 붐빔' || level == '붐빔';
  }

  /// 추천 장소 선택 시 호출
  void _onRecommendedPlaceSelected(PlaceWithZone placeWithZone) {
    if (_insightData == null) return;
    
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
            debugPrint('[ResultMapScreen] 추천 시간대 로드 실패: ${result.message}');
            setState(() {
              _timeTabState = TimeTabState.error;
              _timeTabError = result.message;
            });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 추천 시간대 로드 예외: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
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
    
    // 원래 선택으로 복원 시 활성 탭의 데이터 재로드
    _reloadActiveTabData();
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
        debugPrint('[ResultMapScreen] 검색 매장 마커 추가: ${_baseSelectedPlaceWithZone!.place.name}');
      }
      
      // 추천 매장들 추가 (선택 매장이 아닌 경우)
      for (final rec in recommendationsToUse) {
        if (rec.place.id != selectedPlaceId) {
          allOtherPlaces.add(rec);
        }
      }
      debugPrint('[ResultMapScreen] 추천 매장 마커 추가: ${recommendationsToUse.length}개 중 ${allOtherPlaces.length - (selectedPlaceId != _baseSelectedPlaceWithZone!.place.id ? 1 : 0)}개');
    } else if (_insightData != null && recommendationsToUse.isNotEmpty) {
      // base 스냅샷이 없어도 현재 insightData의 추천 매장은 표시
      final selectedPlaceId = selectedPlace?.id;
      for (final rec in recommendationsToUse) {
        if (rec.place.id != selectedPlaceId) {
          allOtherPlaces.add(rec);
        }
      }
      debugPrint('[ResultMapScreen] 추천 매장 마커 추가 (base 없음): ${recommendationsToUse.length}개');
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
    
    debugPrint('[ResultMapScreen] 마커 표시: 선택 매장=${selectedPlace?.name}, 일반 마커=${recommendedPlaces?.length ?? 0}개, 탭=$_selectedTab');
    
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
              )
            else
              // 지도 로딩 중: 흰 화면 + 돋보기 아이콘 + 문구
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '지도를 불러오고 있어요',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                      // 디버깅용: 혼잡도 선택 리스트 버튼
                      if (_insightData != null) _buildCrowdingLevelSelector(),
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

  /// 디버깅용: 혼잡도 선택 리스트 버튼
  Widget _buildCrowdingLevelSelector() {
    final crowdingLevels = ['여유', '보통', '약간 붐빔', '붐빔'];
    final currentLevel = _displayZone?.crowdingLevel ?? _selectedCrowdingLevel;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8.0, left: 16.0, bottom: 8.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: crowdingLevels.map((level) {
            final isSelected = level == currentLevel;
            return ChoiceChip(
              label: Text(
                level,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _onCrowdingLevelChanged(level);
                }
              },
              selectedColor: _getCrowdingColor(level),
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 혼잡도 레벨에 따른 색상 반환
  Color _getCrowdingColor(String level) {
    switch (level) {
      case '여유':
      case '원활':
        return Colors.green;
      case '보통':
        return const Color(0xFFF9A825); // 가독성 있는 노란색 (amber 800)
      case '약간 붐빔':
        return Colors.deepOrange; // 더 진한 주황색으로 변경
      case '붐빔':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  /// 상단 고정 앵커: 브랜드 아이콘, [기준] 라벨 + 장소명, 다시 검색 버튼
  Widget _buildTopSection(Place selectedPlace) {
    final placeName = selectedPlace.name;

    return Container(
      padding: const EdgeInsets.all(_DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _DesignTokens.grayBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: 브랜드 아이콘 (원형, #FFD700 배경)
          _buildBrandIconWithBg(placeName, size: 40),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
                color: _DesignTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 브랜드 아이콘 with 배경 (#FFD700)
  Widget _buildBrandIconWithBg(String? placeName, {double size = 40}) {
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
                  return _buildPlaceholderIcon(size);
                },
              ),
            )
          : _buildPlaceholderIcon(size),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _DesignTokens.spacing20,
          _DesignTokens.spacing20,
          _DesignTokens.spacing16,
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
                // 접기/펼치기 버튼
                IconButton(
                  icon: Icon(
                    _isBottomSheetExpanded ? Icons.expand_less : Icons.expand_more,
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
                padding: const EdgeInsets.only(top: _DesignTokens.spacing16),
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
        _buildBrandIconWithBg(place.name, size: 48),
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
        horizontal: _DesignTokens.spacing12,
        vertical: _DesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: badgeConfig['bg'],
        borderRadius: BorderRadius.circular(_DesignTokens.radius12),
      ),
      child: Text(
        crowdingLevel.isNotEmpty ? crowdingLevel : '여유',
        style: TextStyle(
          fontSize: 13,
          color: badgeConfig['text'],
          fontWeight: FontWeight.w600,
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
        fontSize: 15,
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
      height: 44,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(_DesignTokens.radius8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _DesignTokens.black : _DesignTokens.grayText,
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
            fontSize: 17,
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
            fontSize: 17,
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
            fontSize: 17,
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
            fontSize: 17,
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
            fontSize: 17,
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
            fontSize: 17,
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
    final headerText = _getPlaceTabHeaderText(zone);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing24),
        _buildEmptyState(
          title: '가까운 범위에는 여유로운 곳이 없어요',
          body: '조금 더 넓게 찾아볼까요?',
          actionButton: ElevatedButton(
            onPressed: _expandRadiusAndRefetch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _DesignTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('범위 넓혀서 찾기'),
          ),
        ),
      ],
    );
  }
  
  /// PLACE 탭 확장 후 빈 상태
  Widget _buildPlaceTabEmptyExpanded(ZoneInfo zone) {
    final headerText = _getPlaceTabHeaderText(zone);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing24),
        _buildEmptyState(
          title: '지금은 주변 대부분이 붐비는 상태예요',
          body: "'시간 바꾸기'에서 한산한 시간대를 확인해보세요",
        ),
      ],
    );
  }
  
  /// PLACE 탭 에러 상태
  Widget _buildPlaceTabError(ZoneInfo zone) {
    final headerText = _getPlaceTabHeaderText(zone);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing24),
        _buildErrorState(
          title: '근처 장소 정보를 불러오지 못했어요',
          body: '잠시 후 다시 시도해 주세요',
          onRetry: _retryPlace,
        ),
      ],
    );
  }
  
  /// 빈 상태 공통 UI
  Widget _buildEmptyState({
    required String title,
    required String body,
    Widget? actionButton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
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
  }
  
  /// 에러 상태 공통 UI
  Widget _buildErrorState({
    required String title,
    required String body,
    required VoidCallback onRetry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
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
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon (44px 원형)
            _buildBrandIcon(place.name, size: 44),
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
  Widget _buildBrandIcon(String? placeName, {double size = 48}) {
    // 브랜드명에서 에셋 경로 찾기
    final brandAssetPath = BrandIconMapper.getBrandIconAsset(placeName);
    
    // 디버깅 로그
    debugPrint('[ResultMapScreen] 브랜드 아이콘 매칭: placeName="$placeName", assetPath=$brandAssetPath');
    
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
                  debugPrint('[ResultMapScreen] 브랜드 아이콘 에셋 로딩 실패: $brandAssetPath, error: $error');
                  return _buildPlaceholderIcon(size);
                },
              )
            : _buildPlaceholderIcon(size),
      ),
    );
  }

  /// Placeholder 아이콘
  Widget _buildPlaceholderIcon(double size) {
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
  }
}
