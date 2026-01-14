import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/brand_icon_mapper.dart';
import '../../../data/models/insight_request.dart';
import '../../../data/models/insight_response.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_with_zone.dart';
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
  bool _isCongestionInverted = false; // 디버깅용: 혼잡도 반전 여부
  bool _isDebugMode = false; // 디버깅 모드 여부
  String _selectedCrowdingLevel = '붐빔'; // 선택된 혼잡도 레벨 (디버깅용)
  Place? _currentSelectedPlace; // 현재 선택된 장소 (recommended place 선택 시 업데이트)
  late AnimationController _animationController; // 애니메이션 컨트롤러
  bool _isBestTimeExpanded = false; // 추천 시간대 아코디언 확장 여부
  RecommendTimesResponse? _recommendTimesData; // 추천 시간대 데이터
  String _selectedTab = 'place'; // 하단 시트의 선택된 탭 ('time' or 'place')
  bool _isLoadingRecommendTimes = false; // 추천 시간대 로딩 상태
  String? _recommendTimesError; // 추천 시간대 에러 메시지
  
  // 임시 선택 상태 관리
  ViewState _viewState = ViewState.baseSelectedView;
  PlaceWithZone? _baseSelectedPlaceWithZone; // 원래 선택된 장소 (스냅샷)
  List<PlaceWithZone> _baseRecommendations = []; // 원래 추천 리스트 (스냅샷)
  PlaceWithZone? _tempSelectedPlaceWithZone; // 임시 선택된 장소

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
      _loadRecommendTimes();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// API 데이터를 로드
  Future<void> _loadInsight() async {
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
      final request = PlacesInsightRequest(
        selected: _currentSelectedPlace!,
        userLat: location.latitude,
        userLng: location.longitude,
        maxAlternatives: 3,
      );

      debugPrint('[ResultMapScreen] 인사이트 데이터 로딩 시작...');
      final result = await _insightRepository.getInsight(request);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<PlacesInsightResponse>():
            final isCongested = result.data.selected.zone.isCongested;
            debugPrint('[ResultMapScreen] ✅ 데이터 로드 성공!');
            debugPrint('[ResultMapScreen] - selected: ${result.data.selected.place.name}');
            debugPrint('[ResultMapScreen] - alternatives: ${result.data.alternatives.length}개');
            debugPrint('[ResultMapScreen] - isCongested: $isCongested');
            debugPrint('[ResultMapScreen] - zone: ${result.data.selected.zone.crowdingLevel}');
            setState(() {
              _insightData = result.data;
              _isLoading = false;
              _showLongLoadingIndicator = false;
              _isDebugMode = false; // 실제 API 모드
              _selectedCrowdingLevel = result.data.selected.zone.crowdingLevel; // 실제 혼잡도로 초기화
              // 검색 매장과 추천 매장 스냅샷 캡처 (한 번만, API 성공 시)
              if (_baseSelectedPlaceWithZone == null) {
                _baseSelectedPlaceWithZone = result.data.selected;
                _baseRecommendations = List.from(result.data.alternatives);
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
            debugPrint('[ResultMapScreen] 디버깅 모드로 전환');
            // API 실패 시 디버깅 모드로 전환
            _loadDebugModeData();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 예외 발생: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        debugPrint('[ResultMapScreen] 디버깅 모드로 전환');
        // 예외 발생 시 디버깅 모드로 전환
        _loadDebugModeData();
      }
    }
  }

  /// 디버깅 모드 데이터 로드
  /// API 실패 시 사용되는 mock 데이터
  void _loadDebugModeData() {
    if (_currentSelectedPlace == null) return;

    debugPrint('[ResultMapScreen] 디버깅 모드 데이터 생성 중...');
    
    // 선택 매장: 검색 결과 사용, 혼잡도는 "붐빔" (매우 혼잡)
    final selectedPlace = _currentSelectedPlace!;
    final selectedZone = ZoneInfo(
      code: 'debug_selected',
      name: selectedPlace.name,
      lat: selectedPlace.latitude,
      lng: selectedPlace.longitude,
      distanceM: selectedPlace.distanceM,
      crowdingLevel: _selectedCrowdingLevel, // 선택된 혼잡도 레벨 사용
      crowdingRank: _selectedCrowdingLevel == '붐빔' ? 1 : 
                    _selectedCrowdingLevel == '약간 붐빔' ? 2 :
                    _selectedCrowdingLevel == '보통' ? 3 : 4,
      crowdingColor: _selectedCrowdingLevel == '붐빔' ? 'red' :
                     _selectedCrowdingLevel == '약간 붐빔' ? 'orange' :
                     _selectedCrowdingLevel == '보통' ? 'yellow' : 'green',
      crowdingUpdatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      crowdingMessage: '디버깅 모드',
    );

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

    final debugData = PlacesInsightResponse(
      selected: PlaceWithZone(
        place: selectedPlace,
        zone: selectedZone,
      ),
      alternatives: recommendedPlaces,
    );

    setState(() {
      _insightData = debugData;
      _isLoading = false;
      _showLongLoadingIndicator = false;
      _isDebugMode = true;
      // 추천 리스트가 처음 표시될 때 base 스냅샷 캡처
      if (debugData.alternatives.isNotEmpty && _viewState == ViewState.baseSelectedView) {
        _baseSelectedPlaceWithZone = debugData.selected;
        _baseRecommendations = List.from(debugData.alternatives);
      }
    });

    debugPrint('[ResultMapScreen] ✅ 디버깅 모드 데이터 생성 완료');
    debugPrint('[ResultMapScreen] - selected: ${selectedPlace.name}, 혼잡도: $_selectedCrowdingLevel');
    debugPrint('[ResultMapScreen] - alternatives: ${recommendedPlaces.length}개');
  }

  /// 혼잡도 레벨 변경 (디버깅용)
  void _onCrowdingLevelChanged(String newLevel) {
    setState(() {
      _selectedCrowdingLevel = newLevel;
    });
    
    // 디버깅 모드인 경우 데이터 다시 생성
    if (_isDebugMode && _insightData != null) {
      _loadDebugModeData();
    } else if (_insightData != null) {
      // 실제 API 모드인 경우 선택된 장소의 혼잡도만 업데이트
      final updatedZone = _insightData!.selected.zone.copyWithCrowdingLevel(newLevel);
      setState(() {
        _insightData = PlacesInsightResponse(
          selected: PlaceWithZone(
            place: _insightData!.selected.place,
            zone: updatedZone,
          ),
          alternatives: _insightData!.alternatives,
        );
      });
    }
  }

  /// 현재 선택된 장소 정보 (API 또는 mock 데이터)
  PlaceWithZone? get _currentPlaceWithZone {
    if (_insightData == null) return null;
    return _insightData!.selected;
  }

  /// 혼잡도 반전을 적용한 ZoneInfo
  /// 디버깅 모드에서는 선택된 혼잡도 레벨 사용
  /// viewState에 따라 현재 선택된 장소의 zone 반환
  ZoneInfo? get _displayZone {
    if (_insightData == null) return null;
    
    // 임시 선택 상태일 때는 임시 선택된 장소의 zone 사용
    final zoneToUse = _viewState == ViewState.tempSelectedFromRecommendation
        ? _insightData!.selected.zone
        : _insightData!.selected.zone;
    
    final baseZone = _isCongestionInverted
        ? zoneToUse.copyWithInvertedCongestion()
        : zoneToUse;
    
    // 디버깅 모드이고 선택된 혼잡도가 다르면 업데이트
    if (_isDebugMode && baseZone.crowdingLevel != _selectedCrowdingLevel) {
      return baseZone.copyWithCrowdingLevel(_selectedCrowdingLevel);
    }
    
    return baseZone;
  }

  /// 혼잡도 반전을 적용한 혼잡 여부 (약간 붐빔 또는 붐빔)
  bool get _isCongested {
    if (_insightData == null) return false;
    final zone = _displayZone ?? _insightData!.selected.zone;
    final level = zone.crowdingLevel;
    return level == '약간 붐빔' || level == '붐빔';
  }

  /// 추천 장소 목록 (최대 3개)
  List<PlaceWithZone> get _recommendedPlaces {
    if (_insightData == null) return [];
    return _insightData!.alternatives.take(3).toList();
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
    
    // 추천 시간대도 새로 로드
    _loadRecommendTimes();
  }
  
  /// 추천 시간대 데이터 로드
  Future<void> _loadRecommendTimes() async {
    if (_currentSelectedPlace == null) return;
    
    setState(() {
      _isLoadingRecommendTimes = true;
      _recommendTimesError = null;
    });
    
    try {
      final result = await _recommendTimesRepository.getRecommendTimes(_currentSelectedPlace!.id);
      
      if (mounted) {
        switch (result) {
          case ApiSuccess<RecommendTimesResponse>():
            setState(() {
              _recommendTimesData = result.data;
              _isLoadingRecommendTimes = false;
            });
          case ApiFailure<RecommendTimesResponse>():
            debugPrint('[ResultMapScreen] 추천 시간대 로드 실패: ${result.message}');
            setState(() {
              _isLoadingRecommendTimes = false;
              _recommendTimesError = result.message;
              // 에러 발생 시 하드코딩된 데이터 사용
              _loadHardcodedRecommendTimes();
            });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 추천 시간대 로드 예외: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingRecommendTimes = false;
          _recommendTimesError = e.toString();
          // 예외 발생 시 하드코딩된 데이터 사용
          _loadHardcodedRecommendTimes();
        });
      }
    }
  }


  /// 추천 장소 탭 핸들러: 선택 매장만 변경 (검색 매장과 추천 매장은 유지)
  void _handleRecommendedPlaceTap(PlaceWithZone placeWithZone) {
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
    
    // 추천 시간대도 새로 로드
    _loadRecommendTimes();
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
    
    // 추천 시간대도 원래 매장 기준으로 다시 로드
    _loadRecommendTimes();
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
    // 검색 매장이 혼잡할 때만 표시 (여유/보통일 때는 표시 안 함)
    // 장소 바꾸기 탭을 선택했어도 검색 매장이 혼잡할 때만 표시
    final baseZone = _baseSelectedPlaceWithZone?.zone;
    final baseIsCongested = baseZone != null && 
                           (baseZone.crowdingLevel == '약간 붐빔' || baseZone.crowdingLevel == '붐빔');
    
    final recommendedPlaces = (baseIsCongested && allOtherPlaces.isNotEmpty) 
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
            MapView(
              selectedPlace: selectedPlace,
              zoneInfo: (!_isLoading) ? _displayZone : null,
              recommendedPlaces: recommendedPlaces,
            ),
            // 3초 이상 로딩 중일 때 원형 프로그레스바 표시
            if (_showLongLoadingIndicator)
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


  /// 상단 고정 앵커: 브랜드 아이콘, (장소명) 기준, 다시 검색 버튼
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
          // Center: (장소명) 기준 텍스트
          Expanded(
            child: Text(
              '$placeName 기준',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _DesignTokens.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
    // 추천 매장 목록 (혼잡할 때만 표시)
    final recommendedPlaces = (_isCongested && _insightData != null)
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
            
            // Section 1: Header - 원형 아이콘 48px, storeName, badge
            _buildBottomSheetHeader(placeWithZone.place, zone),
            
            // Section 2: Status text - "지금은 {혼잡도} 편이에요"
            Padding(
              padding: const EdgeInsets.only(top: _DesignTokens.spacing16),
              child: _buildStatusText(zone.crowdingLevel),
            ),
            
            // Section 3: Segmented control tabs (혼잡할 때만 표시)
            if (isCrowded) ...[
              Padding(
                padding: const EdgeInsets.only(top: _DesignTokens.spacing16),
                child: _buildSegmentedControl(
                  selectedTab: _selectedTab,
                  onTabChanged: (tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
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
      return _buildPlaceTabContent(zone, recommendedPlaces);
    }
  }
  
  /// Time tab content
  Widget _buildTimeTabContent(ZoneInfo zone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          '이때 오면 여유로워요',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        
        // Time list
        if (_isLoadingRecommendTimes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(_DesignTokens.spacing24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recommendTimesError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(_DesignTokens.spacing24),
              child: Text(
                '추천 시간대를 불러올 수 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: _DesignTokens.grayText,
                ),
              ),
            ),
          )
        else if (_recommendTimesData == null || _recommendTimesData!.recommendations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(_DesignTokens.spacing24),
              child: Text(
                '추천 시간대 정보가 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: _DesignTokens.grayText,
                ),
              ),
            ),
          )
        else
          ..._buildTimeList(),
        
        // Footer
        if (_recommendTimesData != null && _recommendTimesData!.recommendations.isNotEmpty) ...[
          const SizedBox(height: _DesignTokens.spacing16),
          const Text(
            '요즘 이 시간대가 쾌적해요',
            style: TextStyle(
              fontSize: 13,
              color: _DesignTokens.grayText,
            ),
          ),
        ],
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
    final isCrowded = zone.crowdingLevel == '약간 붐빔' || zone.crowdingLevel == '붐빔';
    final headerText = (isCrowded || zone.crowdingLevel == '보통')
        ? '근처에 여유로운 곳이 있어요'
        : '지금 바로 갈 수 있어요';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          headerText,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _DesignTokens.black,
          ),
        ),
        const SizedBox(height: _DesignTokens.spacing16),
        
        // Place list
        if (recommendedPlaces.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(_DesignTokens.spacing24),
              child: Text(
                '근처에 여유로운 곳이 없어요',
                style: TextStyle(
                  fontSize: 14,
                  color: _DesignTokens.grayText,
                ),
              ),
            ),
          )
        else
          ...recommendedPlaces.map((placeWithZone) {
            return Padding(
              padding: const EdgeInsets.only(bottom: _DesignTokens.spacing12),
              child: _buildPlaceCard(placeWithZone),
            );
          }).toList(),
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



  /// 하드코딩된 추천 시간대 데이터 로드
  void _loadHardcodedRecommendTimes() {
    // 백엔드 API 응답 구조와 동일한 하드코딩 데이터
    _recommendTimesData = RecommendTimesResponse(
      placeId: _currentSelectedPlace?.id ?? 'hardcoded_place',
      tz: 'Asia/Seoul',
      days: 7,
      minSamples: 3,
      perDay: 3,
      windowH: 2,
      includeLowSamples: false,
      fallbackToHourly: false,
      totalSamples: 50,
      recommendations: [
        // 월요일
        DayRecommendation(
          dow: 0,
          dowName: '월',
          windows: [
            TimeWindow(
              dow: 0,
              dowName: '월',
              startHour: 14,
              endHour: 16,
              label: '14:00-16:00',
              avgRank: 3.5,
              n: 8,
              hours: [14, 15],
              modeLevel: '여유',
              fallback: false,
              confidence: 'high',
              reason: '최근 일주일 동안 월요일 기준 14:00-16:00은 평소보다 덜 붐비는 편이에요, 최근 일주일은 이 시간대가 더 한산한 흐름이었어요.',
            ),
            TimeWindow(
              dow: 0,
              dowName: '월',
              startHour: 10,
              endHour: 12,
              label: '10:00-12:00',
              avgRank: 3.2,
              n: 6,
              hours: [10, 11],
              modeLevel: '여유',
              fallback: false,
              confidence: 'medium',
              reason: '최근 일주일 동안 월요일 기준 10:00-12:00은 평소보다 덜 붐비는 편이에요, 최근 일주일 흐름도 크게 다르지 않았어요.',
            ),
          ],
        ),
        // 화요일
        DayRecommendation(
          dow: 1,
          dowName: '화',
          windows: [
            TimeWindow(
              dow: 1,
              dowName: '화',
              startHour: 15,
              endHour: 17,
              label: '15:00-17:00',
              avgRank: 3.6,
              n: 9,
              hours: [15, 16],
              modeLevel: '여유',
              fallback: false,
              confidence: 'high',
              reason: '최근 일주일 동안 화요일 기준 15:00-17:00은 평소보다 확실히 한산한 편이에요, 최근 일주일은 이 시간대가 더 한산한 흐름이었어요.',
            ),
            TimeWindow(
              dow: 1,
              dowName: '화',
              startHour: 11,
              endHour: 13,
              label: '11:00-13:00',
              avgRank: 3.3,
              n: 7,
              hours: [11, 12],
              modeLevel: '여유',
              fallback: false,
              confidence: 'medium',
              reason: '최근 일주일 동안 화요일 기준 11:00-13:00은 평소보다 덜 붐비는 편이에요, 최근 일주일 흐름도 크게 다르지 않았어요.',
            ),
          ],
        ),
        // 수요일
        DayRecommendation(
          dow: 2,
          dowName: '수',
          windows: [
            TimeWindow(
              dow: 2,
              dowName: '수',
              startHour: 14,
              endHour: 16,
              label: '14:00-16:00',
              avgRank: 3.4,
              n: 8,
              hours: [14, 15],
              modeLevel: '여유',
              fallback: false,
              confidence: 'high',
              reason: '최근 일주일 동안 수요일 기준 14:00-16:00은 평소보다 덜 붐비는 편이에요, 최근 일주일은 이 시간대가 더 한산한 흐름이었어요.',
            ),
          ],
        ),
        // 목요일
        DayRecommendation(
          dow: 3,
          dowName: '목',
          windows: [
            TimeWindow(
              dow: 3,
              dowName: '목',
              startHour: 15,
              endHour: 17,
              label: '15:00-17:00',
              avgRank: 3.5,
              n: 8,
              hours: [15, 16],
              modeLevel: '여유',
              fallback: false,
              confidence: 'high',
              reason: '최근 일주일 동안 목요일 기준 15:00-17:00은 평소보다 덜 붐비는 편이에요, 최근 일주일은 이 시간대가 더 한산한 흐름이었어요.',
            ),
          ],
        ),
        // 금요일
        DayRecommendation(
          dow: 4,
          dowName: '금',
          windows: [
            TimeWindow(
              dow: 4,
              dowName: '금',
              startHour: 10,
              endHour: 12,
              label: '10:00-12:00',
              avgRank: 3.1,
              n: 5,
              hours: [10, 11],
              modeLevel: '여유',
              fallback: false,
              confidence: 'medium',
              reason: '최근 일주일 동안 금요일 기준 10:00-12:00은 평소보다 덜 붐비는 편이에요, 최근 일주일 흐름도 크게 다르지 않았어요.',
            ),
          ],
        ),
        // 토요일
        DayRecommendation(
          dow: 5,
          dowName: '토',
          windows: [
            TimeWindow(
              dow: 5,
              dowName: '토',
              startHour: 9,
              endHour: 11,
              label: '09:00-11:00',
              avgRank: 3.0,
              n: 4,
              hours: [9, 10],
              modeLevel: '여유',
              fallback: false,
              confidence: 'low',
              reason: '최근 일주일 동안 토요일 기준 09:00-11:00은 평소보다 덜 붐비는 편이에요, 최근 일주일 흐름도 크게 다르지 않았어요. 다만 데이터가 아직 적어 참고용이에요',
            ),
          ],
        ),
        // 일요일
        DayRecommendation(
          dow: 6,
          dowName: '일',
          windows: [
            TimeWindow(
              dow: 6,
              dowName: '일',
              startHour: 9,
              endHour: 11,
              label: '09:00-11:00',
              avgRank: 3.2,
              n: 5,
              hours: [9, 10],
              modeLevel: '여유',
              fallback: false,
              confidence: 'medium',
              reason: '최근 일주일 동안 일요일 기준 09:00-11:00은 평소보다 덜 붐비는 편이에요, 최근 일주일 흐름도 크게 다르지 않았어요.',
            ),
          ],
        ),
      ],
    );
  }

  /// Best-time 아코디언 (약간 붐빔, 붐빔일 때만 표시)
  Widget _buildBestTimeLink() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아코디언 헤더 (항상 표시)
          InkWell(
            onTap: () {
              setState(() {
                _isBestTimeExpanded = !_isBestTimeExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isBestTimeExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '이 매장, 덜 붐비는 시간 보기',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _isBestTimeExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.blue,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // 아코디언 내용 (확장 시 표시)
          if (_isBestTimeExpanded && _recommendTimesData != null)
            _buildBestTimeContent(),
        ],
      ),
    );
  }

  /// 추천 시간대 내용 위젯
  Widget _buildBestTimeContent() {
    if (_recommendTimesData == null) return const SizedBox.shrink();

    final recommendations = _recommendTimesData!.recommendations
        .where((rec) => rec.windows.isNotEmpty)
        .toList();

    if (recommendations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '추천 시간대 정보가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 요일별 추천 시간대
          ...recommendations.map((dayRec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요일 헤더
                  Text(
                    '${dayRec.dowName}요일',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 시간대 목록
                  ...dayRec.windows.map((window) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTimeWindowCard(window),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 시간대 카드 위젯
  Widget _buildTimeWindowCard(TimeWindow window) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시간대와 혼잡도 레벨
          Row(
            children: [
              Text(
                window.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _getCrowdingColor(window.modeLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  window.modeLevel.isNotEmpty ? window.modeLevel : '여유',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getCrowdingColor(window.modeLevel),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // 설명 문구
          if (window.reason != null) ...[
            const SizedBox(height: 6),
            Text(
              window.reason!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }


  /// 혼잡도별 상태 메시지 반환
  List<String> _getStatusMessages(String crowdingLevel) {
    switch (crowdingLevel) {
      case '여유':
      case '원활':
        return ['지금은 여유 있어요', '지금 방문해도 괜찮아요'];
      case '보통':
        return ['지금은 사람이 조금 있는 편이에요', '이용하기에 큰 무리는 없어요'];
      case '약간 붐빔':
        return ['지금은 약간 붐비는 편이에요', '조금 덜 붐비는 곳도 함께 볼 수 있어요'];
      case '붐빔':
        return ['지금은 붐비고 있어요', '조금 덜 붐비는 곳도 함께 볼 수 있어요'];
      default:
        return ['혼잡도 정보를 확인하세요'];
    }
  }


  /// 추천 장소 리스트 아이템: 브랜드 아이콘, 장소명, 혼잡도 배지, 거리, chevron
  Widget _buildRecommendedPlaceCard(PlaceWithZone placeWithZone) {
    final place = placeWithZone.place;
    final zone = placeWithZone.zone;

    return InkWell(
      onTap: () => _handleRecommendedPlaceTap(placeWithZone),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 브랜드 아이콘
            _buildBrandIcon(place.name, size: 40),
            const SizedBox(width: 12),
            // 장소 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 장소명 (max 1 line, ellipsis)
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 혼잡도 배지와 거리
                  Row(
                    children: [
                      // 혼잡도 배지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCrowdingColor(zone.crowdingLevel).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          zone.crowdingLevel.isNotEmpty ? zone.crowdingLevel : '여유',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCrowdingColor(zone.crowdingLevel),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 거리
                      if (place.distanceM > 0)
                        Text(
                          '${place.distanceM.toStringAsFixed(0)}m',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 24,
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
