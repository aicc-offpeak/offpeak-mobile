import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/insight_request.dart';
import '../../../data/models/insight_response.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_with_zone.dart';
import '../../../data/models/zone_info.dart';
import '../../../data/repositories/insight_repository.dart';
import '../widgets/map_view.dart';

/// Decision-focused result screen showing selected place and alternatives
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
  String? _error;
  bool _isCongestionInverted = false; // 디버깅용: 혼잡도 반전 여부
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Place? _currentSelectedPlace; // 현재 선택된 매장 (추천 매장 선택 시 변경됨)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _currentSelectedPlace = widget.selectedPlace;
    if (widget.selectedPlace != null) {
      _loadInsight();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInsight({Place? place}) async {
    final targetPlace = place ?? _currentSelectedPlace ?? widget.selectedPlace;
    if (targetPlace == null) return;

    debugPrint('[ResultMapScreen] _loadInsight 호출: targetPlace=${targetPlace.name}, place 파라미터=${place?.name ?? "null"}');

    setState(() {
      _isLoading = true;
      _error = null;
      _currentSelectedPlace = targetPlace;
    });

    try {
      final location = await _locationService.getCurrentPosition();
      final request = PlacesInsightRequest(
        selected: targetPlace,
        userLat: location.latitude,
        userLng: location.longitude,
        maxAlternatives: 3,
      );

      debugPrint('[ResultMapScreen] 인사이트 데이터 로딩 시작... 매장: ${targetPlace.name}');
      final result = await _insightRepository.getInsight(request);
      debugPrint('[ResultMapScreen] 인사이트 데이터 로딩 완료: ${result.runtimeType}');
      
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
            debugPrint('[ResultMapScreen] _currentSelectedPlace 업데이트: ${_currentSelectedPlace?.name}');
            // 혼잡 상태가 변경되면 애니메이션 재시작
            if (isCongested) {
              _animationController.forward();
            } else {
              _animationController.reset();
            }
          case ApiFailure<PlacesInsightResponse>():
            debugPrint('[ResultMapScreen] 데이터 로드 실패: ${result.message}');
            setState(() {
              _error = result.message;
              _isLoading = false;
            });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ResultMapScreen] 예외 발생: $e');
      debugPrint('[ResultMapScreen] 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _error = '혼잡도 정보를 불러오는 중 오류가 발생했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool get _isCongested {
    if (_insightData == null) return false;
    final zone = _isCongestionInverted
        ? _insightData!.selected.zone.copyWithInvertedCongestion()
        : _insightData!.selected.zone;
    return zone.isCongested;
  }

  ZoneInfo? get _displayZone {
    if (_insightData == null) return null;
    return _isCongestionInverted
        ? _insightData!.selected.zone.copyWithInvertedCongestion()
        : _insightData!.selected.zone;
  }

  PlaceWithZone? get _selectedPlaceWithZone {
    if (_insightData == null) return null;
    return _insightData!.selected;
  }

  Place? get _displaySelectedPlace {
    // _insightData가 있으면 그 안의 선택된 매장을 우선 사용
    if (_insightData != null) {
      return _insightData!.selected.place;
    }
    return _currentSelectedPlace ?? widget.selectedPlace;
  }

  List<PlaceWithZone> get _recommendedPlaces {
    if (_insightData == null) return [];
    return _insightData!.alternatives.take(3).toList();
  }

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
    // 추천 매장 선택 시 해당 매장으로 변경하고 인사이트 데이터 다시 로드
    debugPrint('[ResultMapScreen] 추천 매장 탭: ${placeWithZone.place.name}');
    _loadInsight(place: placeWithZone.place);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ResultMapScreen] 🔄 build 호출: widget.selectedPlace=${widget.selectedPlace?.name}, _currentSelectedPlace=${_currentSelectedPlace?.name}, _displaySelectedPlace=${_displaySelectedPlace?.name}, _insightData=${_insightData != null}, _isLoading=$_isLoading, _error=$_error');
    
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
            MapView(
              selectedPlace: _selectedPlaceWithZone?.place ?? _displaySelectedPlace,
              zoneInfo: _displayZone,
              recommendedPlaces: _isCongested ? _recommendedPlaces : [],
            ),
            // 상단 섹션: selectedPlace가 있으면 항상 표시
            if (_displaySelectedPlace != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopAnchorSection(),
                      // 디버깅용: 혼잡도 반전 버튼 (카드 밖)
                      if (_insightData != null) _buildCongestionToggleButton(),
                    ],
                  ),
                ),
              ),
            // selectedPlace가 없을 때 안내 메시지
            if (_displaySelectedPlace == null)
              const Center(
                child: Text(
                  '매장을 선택해주세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            // 로딩 인디케이터
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            // 에러 메시지
            if (_error != null && !_isLoading)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '오류 발생',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadInsight,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            // 하단 섹션: 추천 매장 리스트 (혼잡 시에만 표시)
            if (_isCongested && _insightData != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomSection(),
              ),
            // 하단 섹션: 여유 상태일 때도 표시
            if (!_isCongested && _insightData != null && !_isLoading)
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

  /// 상단 앵커 섹션: "(selectedPlace.name) 기준" + "다시 선택" 버튼
  Widget _buildTopAnchorSection() {
    final displayPlace = _displaySelectedPlace;
    if (displayPlace == null) return const SizedBox.shrink();
    
    final placeName = displayPlace.name;
    final imageUrl = displayPlace.imageUrl;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 브랜드 아이콘
              _buildBrandIcon(imageUrl, size: 40),
              const SizedBox(width: 12),
              // 매장명 텍스트
              Expanded(
                child: Text(
                  '$placeName 기준',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 오른쪽: "다시 선택" 버튼
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, Routes.search);
                },
                child: const Text(
                  '다시 선택',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          // 조건부 버튼: "이 장소, 덜 붐비는 시간 보기 >" (혼잡 시에만 표시, 카드 안에)
          if (_isCongested) _buildLessBusyTimeButton(),
        ],
      ),
    );
  }

  /// 조건부 버튼: "이 장소, 덜 붐비는 시간 보기 >" (혼잡 시에만 표시, 카드 안에)
  Widget _buildLessBusyTimeButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(_fadeAnimation),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                // TODO: 덜 붐비는 시간 보기 기능 구현
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8,
                ),
                alignment: Alignment.centerLeft,
              ),
              child: const Text(
                '이 장소, 덜 붐비는 시간 보기 >',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 하단 섹션: 혼잡 상태일 때 추천 매장 리스트 표시
  Widget _buildBottomSection() {
    if (_insightData == null || _insightData!.alternatives.isEmpty) {
      return const SizedBox.shrink();
    }

    final alternatives = _insightData!.alternatives.take(3).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 메시지 (기존 '추천 매장' 제목 대체)
          const Text(
            '지금은 이곳이 붐벼요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '대신 이 근처는 비교적 여유 있어요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          //const SizedBox(height: 12),
          // 추천 매장 리스트
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: alternatives.length,
              itemBuilder: (context, index) {
                final alt = alternatives[index];
                return _buildRecommendedPlaceItem(
                  PlaceWithZone(place: alt.place, zone: alt.zone),
                );
              },
            ),
          ),
        ],
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

  /// 하단 고정 패널: 혼잡도 상태에 따라 다른 내용 표시
  Widget _buildBottomSheet() {
    debugPrint('[ResultMapScreen] _buildBottomSheet 호출: _selectedPlaceWithZone=${_selectedPlaceWithZone != null}, _isCongested=$_isCongested');
    if (_selectedPlaceWithZone == null) {
      debugPrint('[ResultMapScreen] _buildBottomSheet: _selectedPlaceWithZone가 null이므로 빈 위젯 반환');
      return const SizedBox.shrink();
    }

    debugPrint('[ResultMapScreen] _buildBottomSheet: 패널 빌드 시작 (isCongested=$_isCongested)');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: _isCongested ? _buildBusyStateSheet() : _buildSmoothStateSheet(),
    );
  }

  /// 여유 상태 하단 패널
  Widget _buildSmoothStateSheet() {
    final place = _selectedPlaceWithZone!.place;
    final zone = _displayZone!;
    final imageUrl = place.imageUrl;

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 브랜드 아이콘
              _buildBrandIcon(imageUrl, size: 56),
              const SizedBox(width: 16),
              // 매장명
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 혼잡도 해석 텍스트
                    Text(
                      _getCongestionInterpretation(zone),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 거리 정보
          if (place.distanceM > 0)
            Text(
              '거리: ${place.distanceM.toStringAsFixed(0)}m',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 12),
          // 결론 텍스트
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  '지금 가도 돼요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 혼잡 상태 하단 패널
  Widget _buildBusyStateSheet() {
    final recommendedPlaces = _recommendedPlaces;

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 메시지
          const Text(
            '지금은 이곳이 붐벼요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '대신 이 근처는 비교적 여유 있어요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          // 추천 매장 리스트
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recommendedPlaces.length,
              itemBuilder: (context, index) {
                final placeWithZone = recommendedPlaces[index];
                return _buildRecommendedPlaceItem(placeWithZone);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 추천 매장 리스트 아이템
  Widget _buildRecommendedPlaceItem(PlaceWithZone placeWithZone) {
    final place = placeWithZone.place;
    final zone = placeWithZone.zone;
    final imageUrl = place.imageUrl;

    return InkWell(
      onTap: () => _handleRecommendedPlaceTap(placeWithZone),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            // 브랜드 로고
            _buildBrandIcon(imageUrl, size: 48),
            const SizedBox(width: 12),
            // 매장 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매장명
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 혼잡도 상태
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          zone.crowdingLevel.isNotEmpty
                              ? zone.crowdingLevel
                              : '여유',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 거리
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
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  /// 혼잡도 해석 텍스트 생성
  String _getCongestionInterpretation(ZoneInfo zone) {
    if (zone.crowdingLevel.isEmpty) return '혼잡도 정보 없음';
    return zone.crowdingMessage.isNotEmpty
        ? zone.crowdingMessage
        : '현재 ${zone.crowdingLevel} 상태입니다';
  }

  /// 브랜드 아이콘 빌더 (원형)
  Widget _buildBrandIcon(String? imageUrl, {double size = 48}) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderIcon(size);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  );
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
