import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/insight_request.dart';
import '../../../data/models/insight_response.dart';
import '../../../data/models/place.dart';
import '../../../data/models/zone_info.dart';
import '../../../data/repositories/insight_repository.dart';
import '../widgets/map_view.dart';

/// Android 전용: 지도만 전체 화면으로 표시하는 베이스라인 화면.
class ResultMapScreen extends StatefulWidget {
  final Place? selectedPlace;

  const ResultMapScreen({super.key, this.selectedPlace});

  @override
  State<ResultMapScreen> createState() => _ResultMapScreenState();
}

class _ResultMapScreenState extends State<ResultMapScreen> {
  final _insightRepository = InsightRepository();
  final _locationService = LocationService();

  PlacesInsightResponse? _insightData;
  bool _isLoading = false;
  String? _error;
  bool _isCongestionInverted = false; // 디버깅용: 혼잡도 반전 여부

  @override
  void initState() {
    super.initState();
    if (widget.selectedPlace != null) {
      _loadInsight();
    }
  }

  Future<void> _loadInsight() async {
    if (widget.selectedPlace == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final location = await _locationService.getCurrentPosition();
      final request = PlacesInsightRequest(
        selected: widget.selectedPlace!,
        userLat: location.latitude,
        userLng: location.longitude,
        maxAlternatives: 3,
      );

      final result = await _insightRepository.getInsight(request);
      if (mounted) {
        switch (result) {
          case ApiSuccess<PlacesInsightResponse>():
            setState(() {
              _insightData = result.data;
              _isLoading = false;
            });
          case ApiFailure<PlacesInsightResponse>():
            setState(() {
              _error = result.message;
              _isLoading = false;
            });
        }
      }
    } catch (e) {
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

  void _toggleCongestion() {
    setState(() {
      _isCongestionInverted = !_isCongestionInverted;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            // 사용자 위치는 MapView 내부에서 스트림으로 처리
            MapView(
              selectedPlace: widget.selectedPlace,
              zoneInfo: _displayZone,
            ),
          // 상단 섹션: 가게명, 혼잡도 상태, 추천 시간대 버튼
          if (widget.selectedPlace != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopSection(),
                    // 디버깅용: 혼잡도 반전 버튼 (카드 밖)
                    if (_insightData != null) _buildCongestionToggleButton(),
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
          ],
        ),
      ),
    );
  }

  /// 디버깅용: 혼잡도 반전 버튼 (카드 밖)
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

  Widget _buildTopSection() {
    final placeName = widget.selectedPlace!.name;
    final imageUrl = _insightData?.selected.place.imageUrl ?? widget.selectedPlace!.imageUrl;

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
              // 브랜드 아이콘 (원형)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: _buildBrandIcon(imageUrl, size: 48),
              ),
              Expanded(
                child: Text(
                  placeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
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
          // 추천 시간대 버튼 (혼잡 시에만 표시)
          if (_isCongested)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton(
                onPressed: () {
                  // TODO: 추천 시간대 기능 구현
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  '추천 시간대',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    if (_insightData == null || _insightData!.alternatives.isEmpty) {
      return const SizedBox.shrink();
    }

    final alternatives = _insightData!.alternatives.take(3).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: const Text(
              '추천 매장',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: alternatives.length,
              itemBuilder: (context, index) {
                final alt = alternatives[index];
                final imageUrl = alt.place.imageUrl;
                return ListTile(
                  leading: _buildBrandIcon(imageUrl, size: 48),
                  title: Text(alt.place.name),
                  subtitle: Row(
                    children: [
                      if (alt.place.category.isNotEmpty) ...[
                        Text(
                          alt.place.category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${alt.place.distanceM.toStringAsFixed(0)}m',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alt.zone.crowdingLevel.isNotEmpty
                              ? alt.zone.crowdingLevel
                              : '원활',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // TODO: 추천 매장 선택 시 해당 위치로 이동
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 브랜드 아이콘 빌더 (원형)
  /// imageUrl이 있으면 NetworkImage 사용, 없으면 placeholder 표시
  Widget _buildBrandIcon(String? imageUrl, {double size = 48}) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[200], // placeholder 배경색
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 로딩 실패 시 placeholder 표시
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

  /// Placeholder 아이콘 (기본 아이콘)
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




