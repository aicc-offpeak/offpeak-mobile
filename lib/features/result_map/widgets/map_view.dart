import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// Android 전용 KakaoMap MVP 베이스라인.
/// POI 기반으로 지도 표시. labelLayer.addPoi 사용.
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  KakaoMapController? _controller;
  bool _isMapReady = false;

  // 하드코딩된 마커 좌표 (단일 상수로 정의)
  static const _markerPosition = LatLng(37.4810, 126.8826);
  static const _zoomLevel = 16;
  static const _iconWidth = 64;
  static const _iconHeight = 64;

  @override
  Widget build(BuildContext context) {
    return KakaoMap(
      option: const KakaoMapOption(
        position: _markerPosition,
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
    );
  }

  void _addPoi() {
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] POI 추가 실패: 지도가 아직 준비되지 않음');
      return;
    }

    debugPrint('[MapView] POI 추가 시도: $_markerPosition');

    // labelLayer.addPoi로 아이콘 기반 POI 추가
    // KImage.fromAsset으로 아이콘 사용 (path, width, height 순서)
    try {
      _controller!.labelLayer.addPoi(
        _markerPosition,
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
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] 카메라 이동 실패: 지도가 아직 준비되지 않음');
      return;
    }

    debugPrint('[MapView] 카메라 이동 시도: $_markerPosition');

    // 카메라를 마커 좌표로 이동시켜 화면 정중앙에 마커가 오도록 함
    // KakaoMapOption의 초기 position이 이미 마커 좌표로 설정되어 있으므로,
    // 지도는 자동으로 올바른 위치에 표시됩니다.
    // 추가적인 카메라 이동이 필요한 경우, SDK의 실제 API를 확인하여 사용하세요.
    debugPrint('[MapView] 초기 position 설정으로 인해 지도는 마커 위치에 표시됩니다');
    
    // 참고: kakao_map_sdk의 카메라 이동 메서드는 SDK 버전에 따라 다를 수 있습니다.
    // 현재는 KakaoMapOption의 position으로 초기 위치가 설정되어 있어
    // 지도가 마커 위치에 자동으로 표시됩니다.
  }

  @override
  void dispose() {
    _controller = null;
    _isMapReady = false;
    super.dispose();
  }
}




