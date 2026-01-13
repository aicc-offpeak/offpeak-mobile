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
            setState(() {
              _isLoading = false;
              // TODO: 에러 메시지를 사용자에게 표시할 수 있도록 처리
            });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 예외 발생: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // TODO: 에러 메시지를 사용자에게 표시할 수 있도록 처리
        });
      }
    }
  }

  /// 현재 선택된 장소 정보 (API 또는 mock 데이터)
  PlaceWithZone? get _currentPlaceWithZone {
    if (_insightData == null) return null;
    return _insightData!.selected;
  }

  /// 혼잡도 반전을 적용한 ZoneInfo
  ZoneInfo? get _displayZone {
    if (_insightData == null) return null;
    return _isCongestionInverted
        ? _insightData!.selected.zone.copyWithInvertedCongestion()
        : _insightData!.selected.zone;
  }

  /// 혼잡도 반전을 적용한 혼잡 여부
  bool get _isCongested {
    if (_insightData == null) return false;
    final zone = _isCongestionInverted
        ? _insightData!.selected.zone.copyWithInvertedCongestion()
        : _insightData!.selected.zone;
    return zone.isCongested;
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

  /// 혼잡도 반전 토글 (디버깅용)
  void _toggleCongestion() {
    setState(() {
      _isCongestionInverted = !_isCongestionInverted;
    });
    // 혼잡 상태가 변경되면 애니메이션 재시작
    if (_isCongested) {
      _animationController.forward();
    } else {
      _animationController.reset();
    }
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
              recommendedPlaces: (_insightData != null && _isCongested) ? _recommendedPlaces.map((p) => p.place).toList() : null,
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
                      // 디버깅용: 혼잡도 반전 버튼
                      if (_insightData != null) _buildCongestionToggleButton(),
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

  /// 디버깅용: 혼잡도 반전 버튼
  Widget _buildCongestionToggleButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8.0, left: 16.0),
        width: MediaQuery.of(context).size.width / 3,
        child: OutlinedButton(
          onPressed: _toggleCongestion,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Text(
            _isCongestionInverted
                ? '혼잡도 원래대로 (디버깅)'
                : '혼잡도 반전 (디버깅)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 상단 섹션: "(장소명) 기준" 중앙, "다시 선택" 우측
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
          // "(장소명) 기준" 텍스트
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

  /// 여유 상태 하단 패널
  Widget _buildSmoothStateSheet() {
    if (_currentPlaceWithZone == null) return const SizedBox.shrink();
    final place = _currentPlaceWithZone!.place;
    final zone = _displayZone!;

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 브랜드 아이콘
              _buildBrandIcon(place.name, size: 40),
              const SizedBox(width: 12),
              // "(장소명) 기준" 텍스트
              Expanded(
                child: Text(
                  '${place.name} 기준',
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
          // 조건부: "이 장소, 덜 붐비는 시간 보기 >" 버튼 (혼잡 시에만)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: _isCongested
                ? Align(
                    key: const ValueKey('busy-button'),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2.7),
                      child: TextButton(
                        onPressed: () {
                          // TODO: 덜 붐비는 시간 보기 기능 구현
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3.6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '이 장소, 덜 붐비는 시간 보기 >',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }

  /// 하단 바텀시트: 상태에 따라 smooth 또는 busy 표시
  Widget _buildBottomSheet() {
    if (_currentPlaceWithZone == null) return const SizedBox.shrink();

    final placeWithZone = _currentPlaceWithZone!;
    final zone = _displayZone ?? placeWithZone.zone;

    return Container(
      constraints: BoxConstraints(
        maxHeight: _isCongested ? 400 : 250,
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
      child: _isCongested
          ? _buildBusyBottomSheet(placeWithZone, zone)
          : _buildSmoothBottomSheet(placeWithZone, zone),
    );
  }

  /// Smooth 상태 바텀시트: "지금 가도 돼요"
  Widget _buildSmoothBottomSheet(PlaceWithZone placeWithZone, ZoneInfo zone) {
    final place = placeWithZone.place;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 브랜드 아이콘과 장소명
            Row(
              children: [
                _buildBrandIcon(place.name, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 혼잡도 해석 텍스트
                      Text(
                        _getCongestionInterpretation(zone),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 거리 정보
            if (place.distanceM > 0)
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${place.distanceM.toStringAsFixed(0)}m',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            // 결정 결론 텍스트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                '지금 가도 돼요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Busy 상태 바텀시트: 추천 장소 리스트
  Widget _buildBusyBottomSheet(PlaceWithZone placeWithZone, ZoneInfo zone) {
    final recommendedPlaces = _recommendedPlaces;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '지금은 이곳이 붐벼요.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '대신 이 근처는 비교적 여유 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendedPlaces.length,
            itemBuilder: (context, index) {
              final recommended = recommendedPlaces[index];
              return _buildRecommendedPlaceCard(recommended);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 추천 장소 리스트 아이템
  Widget _buildRecommendedPlaceCard(PlaceWithZone placeWithZone) {
    final place = placeWithZone.place;
    final zone = placeWithZone.zone;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildBrandIcon(place.name, size: 48),
      title: Text(
        place.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      subtitle: Row(
        children: [
          // 혼잡도 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              zone.crowdingLevel.isNotEmpty ? zone.crowdingLevel : '여유',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 거리
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${place.distanceM.toStringAsFixed(0)}m',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _onRecommendedPlaceSelected(placeWithZone),
      splashColor: Colors.transparent,
    );
  }

  /// 혼잡도 해석 텍스트 반환
  String _getCongestionInterpretation(ZoneInfo zone) {
    if (zone.crowdingLevel == '여유' || zone.crowdingLevel == '원활') {
      return '현재 여유로운 상태입니다';
    } else if (zone.crowdingLevel == '약간 붐빔') {
      return '약간 붐비지만 이용 가능합니다';
    } else if (zone.crowdingLevel == '붐빔') {
      return '현재 붐비는 상태입니다';
    }
    return zone.crowdingMessage.isNotEmpty
        ? zone.crowdingMessage
        : '혼잡도 정보를 확인하세요';
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
