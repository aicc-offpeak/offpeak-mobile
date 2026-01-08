import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// Android 전용 KakaoMap MVP 베이스라인.
/// Poi 기반으로 지도 표시.
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  KakaoMapController? _controller;
  bool _isMapReady = false;

  // 하드코딩된 더미 좌표 (서울 강남역)
  static const _dummyLat = 37.4979;
  static const _dummyLng = 127.0276;

  @override
  Widget build(BuildContext context) {
    return KakaoMap(
      option: const KakaoMapOption(
        position: LatLng(_dummyLat, _dummyLng),
        zoomLevel: 16,
      ),
      onMapReady: (controller) {
        setState(() {
          _controller = controller;
          _isMapReady = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}




