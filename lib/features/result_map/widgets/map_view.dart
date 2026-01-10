import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../../core/location/location_service.dart';
import '../../../data/models/place.dart';

/// Android 전용 KakaoMap MVP 베이스라인.
/// POI 기반으로 지도 표시. labelLayer.addPoi 사용.
class MapView extends StatefulWidget {
  final Place? selectedPlace;

  const MapView({super.key, this.selectedPlace});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  KakaoMapController? _controller;
  bool _isMapReady = false;
  LatLng? _currentPosition;
  final _locationService = LocationService();

  static const _zoomLevel = 16;
  static const _iconWidth = 64;
  static const _iconHeight = 64;

  @override
  void initState() {
    super.initState();
    // 선택된 Place가 있으면 그 좌표를 사용, 없으면 현재 위치 사용
    if (widget.selectedPlace != null) {
      _currentPosition = LatLng(
        widget.selectedPlace!.latitude,
        widget.selectedPlace!.longitude,
      );
    } else {
      _loadCurrentPosition();
    }
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final location = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(location.latitude, location.longitude);
        });
      }
    } catch (e) {
      debugPrint('[MapView] 위치 가져오기 실패: $e');
      // 기본값으로 서울 좌표 사용 (에러 발생 시)
      if (mounted) {
        setState(() {
          _currentPosition = const LatLng(37.5665, 126.9780);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 위치를 아직 가져오지 못한 경우 로딩 표시
    if (_currentPosition == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return KakaoMap(
      option: KakaoMapOption(
        position: _currentPosition!,
        zoomLevel: _zoomLevel,
      ),
      onMapReady: (controller) {
        debugPrint('[MapView] onMapReady called - 지도 로딩 완료');
        
        setState(() {
          _controller = controller;
          _isMapReady = true;
        });

        // 지도 준비 완료 후 POI 추가 및 카메라 이동
        _addPoi();
        _moveCameraToMarker();
      },
      onCameraMoveEnd: (position, zoomLevel) {
        debugPrint('[MapView] 카메라 이동 완료: $position, zoom: $zoomLevel');
      },
    );
  }

  void _addPoi() {
    if (!_isMapReady || _controller == null || _currentPosition == null) {
      debugPrint('[MapView] POI 추가 실패: 지도가 아직 준비되지 않음');
      return;
    }

    debugPrint('[MapView] POI 추가 시도: $_currentPosition');

    // labelLayer.addPoi로 아이콘 기반 POI 추가
    // KImage.fromAsset으로 아이콘 사용 (path, width, height 순서)
    try {
      _controller!.labelLayer.addPoi(
        _currentPosition!,
        style: PoiStyle(
          icon: KImage.fromAsset(
            'assets/icons/boom_pin.png',
            _iconWidth,
            _iconHeight,
          ),
        ),
      );
      debugPrint('[MapView] POI 추가 성공');
    } catch (e) {
      debugPrint('[MapView] POI 추가 실패: $e');
    }
  }

  void _moveCameraToMarker() {
    if (!_isMapReady || _controller == null || _currentPosition == null) {
      debugPrint('[MapView] 카메라 이동 실패: 지도가 아직 준비되지 않음');
      return;
    }

    debugPrint('[MapView] 카메라 위치: $_currentPosition');

    // KakaoMapOption의 position이 이미 마커 좌표로 설정되어 있으므로,
    // 지도는 자동으로 올바른 위치에 표시됩니다.
    // kakao_map_sdk의 카메라 이동 API는 버전에 따라 다를 수 있으므로,
    // 초기 position 설정만으로 충분합니다.
    debugPrint('[MapView] 지도가 선택된 위치에 표시됩니다');
  }

  @override
  void dispose() {
    _controller = null;
    _isMapReady = false;
    super.dispose();
  }
}




