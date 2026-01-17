import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/permission.dart';
import '../state/station_anchor_controller.dart';

/// 검색창 아래에 표시되는 위치 맥락 문구 위젯
class LocationContextWidget extends StatefulWidget {
  final StationAnchorController controller;
  final bool isLocationLoading;

  const LocationContextWidget({
    super.key,
    required this.controller,
    this.isLocationLoading = false,
  });

  @override
  State<LocationContextWidget> createState() => _LocationContextWidgetState();
}

class _LocationContextWidgetState extends State<LocationContextWidget> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 1회 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.fetchNearestStation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _buildContent(key: ValueKey(_getContentKey())),
        );
      },
    );
  }

  String _getContentKey() {
    if (widget.isLocationLoading) return 'location-loading';
    if (widget.controller.isLoading) return 'loading';
    if (!widget.controller.hasLocation) return 'no-location';
    if (widget.controller.stationName != null) return 'station';
    return 'no-station';
  }

  Widget _buildContent({required Key key}) {
    // 위치 정보 로딩 중일 때
    if (widget.isLocationLoading) {
      return Padding(
        key: key,
        padding: const EdgeInsets.only(top: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF616161)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '위치를 확인하고 있어요...',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.controller.isLoading) {
      return SizedBox(
        key: key,
        height: 0,
      );
    }

    if (!widget.controller.hasLocation) {
      return Padding(
        key: key,
        padding: const EdgeInsets.only(top: 10.0),
        child: _buildNoLocationText(),
      );
    }

    if (widget.controller.stationName != null) {
      return Padding(
        key: key,
        padding: const EdgeInsets.only(top: 10.0),
        child: Text(
          '지금은 ${widget.controller.stationName} 근처예요',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF777777),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 역 조회 실패 (위치는 있음)
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 10.0),
      child: const Text(
        '지금 있는 곳 근처에서 보고 있어요',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF777777),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNoLocationText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF777777),
        ),
        children: [
          TextSpan(
            text: '내 위치',
            style: const TextStyle(
              color: Color(0xFF6BCF7F), // 브랜드 컬러
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = _handleLocationTap,
          ),
          const TextSpan(text: '를 알면 근처 상황을 더 잘 보여줄 수 있어요'),
        ],
      ),
    );
  }

  Future<void> _handleLocationTap() async {
    if (!mounted) return;

    final locationService = LocationService();
    
    // 위치 권한 확인
    var permissionStatus = await locationService.checkPermission();
    
    if (permissionStatus == LocationPermissionStatus.denied) {
      // 권한 요청
      permissionStatus = await locationService.requestPermission();
      if (permissionStatus != LocationPermissionStatus.granted) {
        return;
      }
    }

    // 위치 서비스 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // OS 위치 설정 화면으로 유도
      await Geolocator.openLocationSettings();
      return;
    }

    // 위치 재획득 및 역 조회 재시도
    if (mounted) {
      await widget.controller.requestLocationAndFetch();
    }
  }
}
