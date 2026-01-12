import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../../core/location/location_service.dart';
import '../../../data/models/place.dart';
import '../../../data/models/zone_info.dart';

/// Android 전용 KakaoMap MVP 베이스라인.
/// POI 기반으로 지도 표시. labelLayer.addPoi 사용.
class MapView extends StatefulWidget {
  final Place? selectedPlace;
  final ZoneInfo? zoneInfo;

  const MapView({
    super.key,
    this.selectedPlace,
    this.zoneInfo,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  KakaoMapController? _controller;
  bool _isMapReady = false;
  LatLng? _currentPosition;
  final _locationService = LocationService();
  dynamic _currentPoi; // 현재 표시 중인 POI (Poi 타입이 불확실하므로 dynamic 사용)
  dynamic _userLocationPoi; // 사용자 위치 POI
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _lastUserLocationPoiPosition; // 마지막으로 POI를 생성한 위치 (throttle용)
  DateTime? _lastUserLocationUpdateTime; // 마지막 업데이트 시간 (throttle용)

  static const _zoomLevel = 16;
  
  // 마커 이미지 크기 (원본 PNG 비율 유지: 가로 11 : 세로 7)
  // map_marker.png의 원본 비율 11:7을 유지
  // 예: 110x70, 165x105, 220x140 등
  static const double _markerWidth = 110.0;  // 11의 배수
  static const double _markerHeight = 70.0;  // 7의 배수 (11:7 비율 유지)
  
  // 사용자 위치 마커 크기 (원래 크기의 1/3)
  static const int _userLocationMarkerSize = 13;

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
    // 사용자 위치 스트림 구독 시작
    _startLocationStream();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // zoneInfo나 selectedPlace가 변경되면 POI 업데이트 및 카메라 이동
    if (widget.zoneInfo != oldWidget.zoneInfo ||
        widget.selectedPlace?.id != oldWidget.selectedPlace?.id) {
      // 선택된 매장이 변경되면 위치 업데이트 및 카메라 이동
      if (widget.selectedPlace != null) {
        setState(() {
          _currentPosition = LatLng(
            widget.selectedPlace!.latitude,
            widget.selectedPlace!.longitude,
          );
        });
        _moveCameraToMarker();
      }
      // 비동기 함수이므로 에러 처리 추가
      _updateSelectedPlacePoi().catchError((e) {
        debugPrint('[MapView] POI 업데이트 에러 (didUpdateWidget): $e');
      });
    }
    // 사용자 위치는 스트림으로 처리하므로 didUpdateWidget에서는 처리하지 않음
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
        debugPrint('[MapView] ✅ onMapReady called - 지도 로딩 완료');
        debugPrint('[MapView] controller: $controller');
        debugPrint('[MapView] selectedPlace: ${widget.selectedPlace?.name}');
        
        setState(() {
          _controller = controller;
          _isMapReady = true;
        });

        debugPrint('[MapView] 상태 업데이트 완료: _isMapReady=$_isMapReady, _controller=${_controller != null}');

        // 지도 준비 완료 후 카메라 이동 및 POI 추가
        _moveCameraToMarker();
        debugPrint('[MapView] _updateSelectedPlacePoi 호출 전');
        // 비동기 함수이므로 에러 처리 추가
        _updateSelectedPlacePoi().catchError((e) {
          debugPrint('[MapView] POI 업데이트 에러: $e');
        });
        // 지도 준비 완료 후 현재 위치를 가져와서 POI 추가
        _loadInitialUserLocation().catchError((e) {
          debugPrint('[MapView] 초기 사용자 위치 로드 에러: $e');
        });
        debugPrint('[MapView] _updateSelectedPlacePoi 호출 후');
      },
      onCameraMoveEnd: (cameraPosition, zoomLevel) {
        debugPrint('[MapView] 카메라 이동 완료: $cameraPosition, zoom: $zoomLevel');
        // 카메라 이동은 기본 지도 동작에 맡기고, POI는 지도 엔진이 자동으로 따라감
      },
    );
  }


  /// 선택 매장 POI 업데이트 (기존 POI 제거 후 새 POI 추가)
  Future<void> _updateSelectedPlacePoi() async {
    debugPrint('[MapView] _updateSelectedPlacePoi 호출됨');
    debugPrint('[MapView] _isMapReady: $_isMapReady, _controller: ${_controller != null}');
    debugPrint('[MapView] selectedPlace: ${widget.selectedPlace?.name}');
    
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] POI 업데이트 스킵: 지도가 준비되지 않음');
      return;
    }

    // 기존 POI 제거
    if (_currentPoi != null) {
      try {
        debugPrint('[MapView] 기존 POI 제거 시도: $_currentPoi');
        // _currentPoi는 이미 Poi 객체이므로 직접 사용
        await _controller!.labelLayer.removePoi(_currentPoi!);
        _currentPoi = null;
        debugPrint('[MapView] 기존 POI 제거 완료');
      } catch (e) {
        debugPrint('[MapView] POI 제거 실패: $e');
        // 에러가 발생해도 계속 진행
      }
    }

    // 선택 매장이 없으면 종료
    if (widget.selectedPlace == null) {
      debugPrint('[MapView] POI 업데이트 스킵: selectedPlace가 null');
      return;
    }

    // 새 POI 추가
    final placeName = widget.selectedPlace!.name;
    final statusText = widget.zoneInfo?.isCongested == true ? '혼잡' : '원활';
    final poiText = '$placeName\n$statusText';

    debugPrint('[MapView] 새 POI 추가 시도: $poiText');
    debugPrint('[MapView] 위치: ${widget.selectedPlace!.latitude}, ${widget.selectedPlace!.longitude}');

    try {
      final position = LatLng(
        widget.selectedPlace!.latitude,
        widget.selectedPlace!.longitude,
      );

      // POI 추가 (텍스트와 스타일 설정)
      try {
        debugPrint('[MapView] POI 추가 시도: $poiText');
        
        // PoiStyle에 PNG 기반 아이콘 설정
        // assets/icons/map_marker.png를 사용하여 마커 표시
        // 원본 PNG 비율을 유지하여 찌그러짐 방지
        // KImage.fromAsset은 3개의 positional argument를 받음: (assetPath, width, height)
        final markerIcon = KImage.fromAsset(
          'assets/icons/map_marker.png',
          _markerWidth.toInt(), // 원본 비율 유지
          _markerHeight.toInt(), // 원본 비율 유지
        );
        
        // anchor는 KPoint 타입을 사용 (x, y = 아이콘 하단 중앙)
        // 포인터(꼬리) 기준으로 하단 중앙에 위치하도록 설정
        final poiStyle = PoiStyle(
          icon: markerIcon,
          anchor: KPoint(0.5, 1.0), // 아이콘 하단 중앙에 위치 (포인터 기준)
          applyDpScale: true,
        );
        
        debugPrint('[MapView] PoiStyle 생성: icon=map_marker.png, size=${_markerWidth.toInt()}x${_markerHeight.toInt()}, anchor=(0.5, 1.0)');
        
        // addPoi는 Future<Poi>를 반환하므로 await 필요
        // text 파라미터로 텍스트 전달
        // style 파라미터는 필수이므로 PoiStyle() 사용
        final addedPoi = await _controller!.labelLayer.addPoi(
          position,
          text: poiText,
          style: poiStyle,
        );
        
        // POI가 실제로 추가되었는지 확인
        debugPrint('[MapView] POI 추가 후 labelLayer 상태 확인');
        
        _currentPoi = addedPoi;
        debugPrint('[MapView] ✅ POI 추가 성공: $poiText');
        debugPrint('[MapView] 추가된 POI: $addedPoi');
        debugPrint('[MapView] POI 위치: ${position.latitude}, ${position.longitude}');
        
        // POI가 추가되었는지 확인하기 위해 약간의 지연 후 상태 확인
        Future.delayed(const Duration(milliseconds: 500), () {
          debugPrint('[MapView] POI 추가 후 상태 확인: _currentPoi=${_currentPoi != null}');
        });
      } catch (e) {
        debugPrint('[MapView] ❌ POI 추가 실패: $e');
        debugPrint('[MapView] 에러 타입: ${e.runtimeType}');
        debugPrint('[MapView] 에러 스택: ${e.toString()}');
        rethrow;
      }
    } catch (e) {
      debugPrint('[MapView] ❌ POI 추가 최종 실패: $e');
      debugPrint('[MapView] 에러 타입: ${e.runtimeType}');
      debugPrint('[MapView] 에러 스택: ${e.toString()}');
    }
  }

  /// 위치 스트림 구독 시작
  void _startLocationStream() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.getPositionStream(
      distanceFilter: 5,
    ).listen(
      (location) {
        if (!mounted) return;
        debugPrint('[MapView] 위치 스트림 업데이트: ${location.latitude}, ${location.longitude}');
        _updateUserLocationPoiFromStream(
          LatLng(location.latitude, location.longitude),
        );
      },
      onError: (error) {
        debugPrint('[MapView] ❌ 위치 스트림 에러: $error');
        debugPrint('[MapView] 위치 권한을 확인하세요.');
      },
      cancelOnError: false, // 에러 발생해도 스트림 계속 유지
    );
  }

  /// 지도 준비 완료 후 초기 사용자 위치 로드 및 POI 추가
  Future<void> _loadInitialUserLocation() async {
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] 초기 사용자 위치 로드 스킵: 지도가 준비되지 않음');
      return;
    }

    try {
      debugPrint('[MapView] 초기 사용자 위치 가져오는 중...');
      final location = await _locationService.getCurrentPosition();
      if (!mounted) return;
      
      debugPrint('[MapView] 초기 사용자 위치: ${location.latitude}, ${location.longitude}');
      final locationLatLng = LatLng(location.latitude, location.longitude);
      // 초기 위치는 throttle 없이 바로 추가
      _lastUserLocationPoiPosition = locationLatLng;
      _lastUserLocationUpdateTime = DateTime.now();
      await _updateUserLocationPoi(locationLatLng);
      debugPrint('[MapView] ✅ 초기 사용자 위치 POI 추가 완료');
    } catch (e) {
      debugPrint('[MapView] ❌ 초기 사용자 위치 로드 실패: $e');
      debugPrint('[MapView] 위치 권한을 확인하거나 위치 서비스를 활성화하세요.');
    }
  }

  /// 스트림에서 받은 위치로 POI 업데이트 (throttle 적용)
  Future<void> _updateUserLocationPoiFromStream(LatLng newLocation) async {
    // Throttle 체크: 최소 500ms 간격
    final now = DateTime.now();
    if (_lastUserLocationUpdateTime != null) {
      final timeDiff = now.difference(_lastUserLocationUpdateTime!);
      if (timeDiff.inMilliseconds < 500) {
        return; // 너무 빨리 업데이트 요청이 들어오면 스킵
      }
    }

    // Throttle 체크: 최소 5m 거리 이동
    if (_lastUserLocationPoiPosition != null) {
      final distance = _calculateDistance(
        _lastUserLocationPoiPosition!.latitude,
        _lastUserLocationPoiPosition!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      if (distance < 5.0) {
        return; // 5m 미만 이동이면 스킵
      }
    }

    // 업데이트 시간 및 위치 저장
    _lastUserLocationUpdateTime = now;
    _lastUserLocationPoiPosition = newLocation;

    // POI 업데이트
    await _updateUserLocationPoi(newLocation);
  }

  /// 두 좌표 간 거리 계산 (미터 단위)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine 공식 사용
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  /// 사용자 위치 POI 업데이트
  Future<void> _updateUserLocationPoi(LatLng location) async {
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] 사용자 위치 POI 업데이트 스킵: 지도가 준비되지 않음');
      return;
    }

    // 기존 사용자 위치 POI 제거 (POI 1개만 유지)
    if (_userLocationPoi != null) {
      try {
        await _controller!.labelLayer.removePoi(_userLocationPoi!);
        _userLocationPoi = null;
        debugPrint('[MapView] 기존 사용자 위치 POI 제거 완료');
      } catch (e) {
        debugPrint('[MapView] 사용자 위치 POI 제거 실패: $e');
      }
    }

    // 새 사용자 위치 POI 추가
    try {
      // user_loc.png 사용 (40x40, anchor 0.5, 0.5, text 없음)
      final markerIcon = KImage.fromAsset(
        'assets/icons/user_loc.png',
        _userLocationMarkerSize,
        _userLocationMarkerSize,
      );
      
      final poiStyle = PoiStyle(
        icon: markerIcon,
        anchor: KPoint(0.5, 0.5), // 중앙 정렬
        applyDpScale: true,
      );
      
      final addedPoi = await _controller!.labelLayer.addPoi(
        location,
        style: poiStyle,
        // text는 표시하지 않음 (가독성/겹침 방지)
      );
      
      _userLocationPoi = addedPoi;
      debugPrint('[MapView] ✅ 사용자 위치 POI 추가 성공');
      debugPrint('[MapView] 사용자 위치: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      debugPrint('[MapView] ❌ 사용자 위치 POI 추가 실패: $e');
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
    debugPrint('[MapView] 지도가 선택된 위치에 표시됩니다');
  }

  @override
  void dispose() {
    // 위치 스트림 구독 취소
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    // POI 정리 (비동기이지만 dispose에서는 await 불가)
    if (_controller != null && _currentPoi != null) {
      try {
        // _currentPoi가 Future인 경우 처리
        if (_currentPoi is Future) {
          (_currentPoi as Future).then((poi) {
            _controller?.labelLayer.removePoi(poi);
          }).catchError((e) {
            debugPrint('[MapView] POI 정리 실패: $e');
          });
        } else {
          _controller!.labelLayer.removePoi(_currentPoi!);
        }
      } catch (e) {
        debugPrint('[MapView] POI 정리 실패: $e');
      }
    }
    // 사용자 위치 POI 정리
    if (_controller != null && _userLocationPoi != null) {
      try {
        if (_userLocationPoi is Future) {
          (_userLocationPoi as Future).then((poi) {
            _controller?.labelLayer.removePoi(poi);
          }).catchError((e) {
            debugPrint('[MapView] 사용자 위치 POI 정리 실패: $e');
          });
        } else {
          _controller!.labelLayer.removePoi(_userLocationPoi!);
        }
      } catch (e) {
        debugPrint('[MapView] 사용자 위치 POI 정리 실패: $e');
      }
    }
    _controller = null;
    _isMapReady = false;
    _currentPoi = null;
    _userLocationPoi = null;
    _lastUserLocationPoiPosition = null;
    _lastUserLocationUpdateTime = null;
    super.dispose();
  }
}




