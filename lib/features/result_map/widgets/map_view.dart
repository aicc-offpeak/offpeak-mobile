import 'package:flutter/foundation.dart';
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

  // 하드코딩된 좌표 및 POI 텍스트
  static const _lat = 37.4810;
  static const _lng = 126.8826;
  static const _zoomLevel = 16;
  static const _poiText = "테스트 마커";

  @override
  Widget build(BuildContext context) {
    return KakaoMap(
      option: const KakaoMapOption(
        position: LatLng(_lat, _lng),
        zoomLevel: _zoomLevel,
      ),
      onMapReady: (controller) {
        debugPrint('[MapView] onMapReady called - 지도 로딩 완료');
        
        setState(() {
          _controller = controller;
          _isMapReady = true;
        });

        // 지도 준비 완료 후 POI 추가
        _addPoi();
        
      },
    );
  }

  void _addPoi() {
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] POI 추가 실패: 지도가 아직 준비되지 않음');
      return;
    }

    debugPrint('[MapView] POI 추가 시도: ($_lat, $_lng) - "$_poiText"');

    // labelLayer.addPoi로 텍스트 기반 POI 추가
    // addPoi는 LatLng를 첫 번째 인자로 받고, text와 style을 named parameter로 받음
    try {
      _controller!.labelLayer.addPoi(
        const LatLng(_lat, _lng),
        text: _poiText,
        style: PoiStyle(),
      );
      debugPrint('[MapView] POI 추가 성공');
    } catch (e) {
      debugPrint('[MapView] POI 추가 실패: $e');
    }
  }

  @override
  void dispose() {
    _controller = null;
    _isMapReady = false;
    super.dispose();
  }
}




