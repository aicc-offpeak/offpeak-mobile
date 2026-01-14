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
import '../../../data/models/zone_info.dart';
import '../../../data/repositories/insight_repository.dart';
import '../widgets/map_view.dart';

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
  final _locationService = LocationService();

  PlacesInsightResponse? _insightData;
  bool _isLoading = false;
  bool _isCongestionInverted = false; // 디버깅용: 혼잡도 반전 여부
  bool _isDebugMode = false; // 디버깅 모드 여부
  String _selectedCrowdingLevel = '붐빔'; // 선택된 혼잡도 레벨 (디버깅용)
  Place? _currentSelectedPlace; // 현재 선택된 장소 (recommended place 선택 시 업데이트)
  late AnimationController _animationController; // 애니메이션 컨트롤러

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
              _isDebugMode = false; // 실제 API 모드
              _selectedCrowdingLevel = result.data.selected.zone.crowdingLevel; // 실제 혼잡도로 초기화
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
      _isDebugMode = true;
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
  ZoneInfo? get _displayZone {
    if (_insightData == null) return null;
    final baseZone = _isCongestionInverted
        ? _insightData!.selected.zone.copyWithInvertedCongestion()
        : _insightData!.selected.zone;
    
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
    setState(() {
      _currentSelectedPlace = placeWithZone.place;
    });
    _loadInsight();
  }


  void _handleRecommendedPlaceTap(PlaceWithZone placeWithZone) {
    // TODO: 추천 매장 선택 시 해당 위치로 이동 및 선택 상태 업데이트
    // 현재는 화면을 다시 로드하지 않고 상태만 업데이트
    setState(() {
      // 선택된 매장을 추천 매장으로 변경
      _insightData = PlacesInsightResponse(
        selected: placeWithZone,
        alternatives: _insightData!.alternatives
            .where((alt) => alt.place.id != placeWithZone.place.id)
            .toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlace = _currentPlaceWithZone?.place ?? _currentSelectedPlace;
    
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
              recommendedPlaces: (_insightData != null && _isCongested && _recommendedPlaces.isNotEmpty) 
                  ? _recommendedPlaces.take(3).toList() 
                  : null,
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
        return Colors.yellow.shade700;
      case '약간 붐빔':
        return Colors.deepOrange; // 더 진한 주황색으로 변경
      case '붐빔':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  /// 상단 고정 앵커: 브랜드 아이콘, (장소명) 기준, 다시 선택 버튼
  Widget _buildTopSection(Place selectedPlace) {
    final placeName = selectedPlace.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 브랜드 아이콘
          _buildBrandIcon(placeName, size: 40),
          const SizedBox(width: 12),
          // (장소명) 기준 텍스트
          Expanded(
            child: Text(
              '$placeName 기준',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // 우측에 "다시 선택" 버튼
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, Routes.search);
            },
            child: const Text(
              '다시 선택',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// 하단 바텀시트: 통일된 구조로 모든 혼잡도 상태 표시
  Widget _buildBottomSheet() {
    if (_currentPlaceWithZone == null) return const SizedBox.shrink();

    final placeWithZone = _currentPlaceWithZone!;
    final zone = _displayZone ?? placeWithZone.zone;
    final isCrowded = zone.crowdingLevel == '약간 붐빔' || zone.crowdingLevel == '붐빔';
    final recommendedPlaces = _recommendedPlaces;
    
    // 높이 계산: 기본 메시지 + (혼잡 시 best-time 링크) + (혼잡 시 추천 리스트)
    final estimatedHeight = isCrowded && recommendedPlaces.isNotEmpty
        ? 300.0 + (recommendedPlaces.length * 80.0) // 각 추천 항목당 약 80px
        : 150.0; // 기본 메시지만

    return Container(
      constraints: BoxConstraints(
        maxHeight: estimatedHeight.clamp(150.0, 500.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
    final recommendedPlaces = _recommendedPlaces;
    final statusMessages = _getStatusMessages(zone.crowdingLevel);
    final isCrowded = zone.crowdingLevel == '약간 붐빔' || zone.crowdingLevel == '붐빔';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 선택 매장 인라인 요약 (모든 혼잡도에서 표시)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _buildSelectedPlaceInlineSummary(placeWithZone.place, zone),
          ),
          
          // 2. 추천 시간대 버튼 (약간 붐빔, 붐빔일 때만 표시)
          if (isCrowded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: _buildBestTimeLink(),
            ),
            const SizedBox(height: 8),
          ],
          
          // 3. 상태 메시지와 가이던스
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _buildStatusAndGuidance(statusMessages),
          ),
          
          // 4. 선택적 추천 장소 리스트 (약간 붐빔, 붐빔일 때만)
          if (isCrowded && recommendedPlaces.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...recommendedPlaces.map((recommended) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildRecommendedPlaceCard(recommended),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 상태 메시지와 가이던스
  Widget _buildStatusAndGuidance(List<String> statusMessages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 상태: 혼잡도 레벨에 따른 메인 메시지 (large bold)
        Text(
          statusMessages[0],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        // 가이던스: 혼잡도 레벨에 따른 보조 메시지 (small secondary)
        if (statusMessages.length > 1) ...[
          const SizedBox(height: 4),
          Text(
            statusMessages[1],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  /// 선택 매장 인라인 요약: 브랜드 아이콘, 장소명, 혼잡도 배지 (best-time 링크 위에 표시)
  Widget _buildSelectedPlaceInlineSummary(Place place, ZoneInfo zone) {
    return Row(
      children: [
        // 브랜드 아이콘 (작은 크기)
        _buildBrandIcon(place.name, size: 32),
        const SizedBox(width: 8),
        // 장소명
        Expanded(
          child: Text(
            place.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // 혼잡도 배지 (작은 크기)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _getCrowdingColor(zone.crowdingLevel).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            zone.crowdingLevel.isNotEmpty ? zone.crowdingLevel : '여유',
            style: TextStyle(
              fontSize: 11,
              color: _getCrowdingColor(zone.crowdingLevel),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Best-time 링크 (약간 붐빔, 붐빔일 때만 표시)
  Widget _buildBestTimeLink() {
    return TextButton(
      onPressed: () {
        // TODO: 덜 붐비는 시간 보기 기능 구현
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        '이 매장, 덜 붐비는 시간 보기',
        style: TextStyle(
          fontSize: 14,
          color: Colors.blue,
          fontWeight: FontWeight.w500,
        ),
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
