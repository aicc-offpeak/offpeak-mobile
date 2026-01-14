import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../core/location/location_service.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_with_zone.dart';
import '../../../data/models/zone_info.dart';

/// Android 전용 KakaoMap MVP 베이스라인.
/// POI 기반으로 지도 표시. labelLayer.addPoi 사용.
class MapView extends StatefulWidget {
  final Place? selectedPlace;
  final ZoneInfo? zoneInfo;
  final List<PlaceWithZone>? recommendedPlaces; // 추천 장소 목록 (혼잡 시 표시, zoneInfo 포함)

  const MapView({
    super.key,
    this.selectedPlace,
    this.zoneInfo,
    this.recommendedPlaces,
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
  List<dynamic> _recommendedPois = []; // 추천 장소 POI 목록
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _lastUserLocationPoiPosition; // 마지막으로 POI를 생성한 위치 (throttle용)
  DateTime? _lastUserLocationUpdateTime; // 마지막 업데이트 시간 (throttle용)

  static const _zoomLevel = 16;
  
  // 마커 이미지 크기 (가로 2: 세로 3 비율)
  // 기본 크기를 선택 매장 기준으로 설정 (기존 기본의 75%)
  // 2:3 비율: 21x32 (기존 28x42의 75%, 21 * 1.5 = 31.5 → 32로 반올림)
  static const double _markerWidth = 21.0;   // 2:3 비율의 가로 (기본 크기)
  static const double _markerHeight = 32.0;  // 2:3 비율의 세로 (기본 크기)
  
  // 사용자 위치 마커 크기 (원래 크기의 1/3)
  static const int _userLocationMarkerSize = 13;

  // 브랜드 아이콘 캐시 (URL -> 로컬 파일 경로)
  final Map<String, String> _brandIconCache = {};
  final Dio _dio = Dio();

  /// 혼잡도에 따라 선택 매장 마커 이미지 경로 반환
  /// zoneInfo가 null이면 회색 마커 (API 실패 또는 정보 없음)
  /// 주의: KakaoMap SDK는 하위 폴더를 지원하지 않을 수 있으므로 icons/ 직하위에 파일명으로 구분
  String _getSelectedMarkerImagePath(ZoneInfo? zoneInfo) {
    if (zoneInfo == null || zoneInfo.crowdingLevel.isEmpty) {
      return 'assets/icons/marker_selected_grey.png'; // 정보 없음
    }

    final crowdingLevel = zoneInfo.crowdingLevel;
    
    if (crowdingLevel == '여유' || crowdingLevel == '원활') {
      return 'assets/icons/marker_selected_green.png';
    } else if (crowdingLevel == '보통') {
      return 'assets/icons/marker_selected_yellow.png';
    } else if (crowdingLevel == '약간 붐빔') {
      return 'assets/icons/marker_selected_orange.png';
    } else if (crowdingLevel == '붐빔') {
      return 'assets/icons/marker_selected_red.png';
    }
    
    return 'assets/icons/marker_selected_grey.png'; // 알 수 없는 혼잡도 레벨
  }

  /// 혼잡도에 따라 추천 매장 마커 이미지 경로 반환
  /// 추천 매장은 일반적으로 여유 상태이므로 green 사용
  /// 주의: KakaoMap SDK는 하위 폴더를 지원하지 않을 수 있으므로 icons/ 직하위에 파일명으로 구분
  /// 추천 매장 마커는 marker_*.png 형식 (selected가 없음)
  String _getRecommendedMarkerImagePath(ZoneInfo? zoneInfo) {
    if (zoneInfo == null || zoneInfo.crowdingLevel.isEmpty) {
      return 'assets/icons/marker_grey.png'; // 정보 없음
    }

    final crowdingLevel = zoneInfo.crowdingLevel;
    
    if (crowdingLevel == '여유' || crowdingLevel == '원활') {
      return 'assets/icons/marker_green.png';
    } else if (crowdingLevel == '보통') {
      return 'assets/icons/marker_yellow.png';
    } else if (crowdingLevel == '약간 붐빔') {
      return 'assets/icons/marker_orange.png';
    } else if (crowdingLevel == '붐빔') {
      return 'assets/icons/marker_red.png';
    }
    
    return 'assets/icons/marker_grey.png'; // 알 수 없는 혼잡도 레벨
  }

  /// 브랜드 아이콘을 다운로드하고 로컬 파일 경로 반환
  /// 실패 시 null 반환
  Future<String?> _downloadBrandIcon(String? imageUrl) async {
    // imageUrl이 없거나 비어있으면 null 반환
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    // 캐시에 있으면 캐시된 경로 반환
    if (_brandIconCache.containsKey(imageUrl)) {
      final cachedPath = _brandIconCache[imageUrl]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      } else {
        // 캐시된 파일이 없으면 캐시에서 제거
        _brandIconCache.remove(imageUrl);
      }
    }

    try {
      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(path.join(tempDir.path, 'brand_icons'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // URL에서 파일명 생성 (해시 사용)
      final urlHash = imageUrl.hashCode.toString();
      final extension = path.extension(imageUrl).isNotEmpty 
          ? path.extension(imageUrl) 
          : '.png';
      final fileName = 'brand_$urlHash$extension';
      final filePath = path.join(cacheDir.path, fileName);

      // 이미 파일이 있으면 파일 경로 반환
      if (await File(filePath).exists()) {
        _brandIconCache[imageUrl] = filePath;
        return filePath;
      }

      // 네트워크에서 이미지 다운로드
      debugPrint('[MapView] 브랜드 아이콘 다운로드 중: $imageUrl');
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        
        // 파일로 저장 (캐싱)
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // 캐시에 추가
        _brandIconCache[imageUrl] = filePath;
        debugPrint('[MapView] ✅ 브랜드 아이콘 다운로드 완료: $filePath');
        return filePath;
      } else {
        debugPrint('[MapView] ❌ 브랜드 아이콘 다운로드 실패: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[MapView] ❌ 브랜드 아이콘 다운로드 에러: $e');
      return null;
    }
  }

  /// 마커 아이콘 생성 (브랜드 아이콘 또는 기본 마커)
  /// isRecommended가 true면 추천 매장 마커, false면 선택 매장 마커 사용
  Future<KImage> _createMarkerIcon(
    Place? place, 
    ZoneInfo? zoneInfo, {
    bool isRecommended = false,
    double widthMultiplier = 1.0, 
    double heightMultiplier = 1.0,
  }) async {
    // 브랜드 아이콘 URL이 있으면 다운로드하여 캐시에 저장 (백그라운드)
    if (place?.imageUrl != null && place!.imageUrl.isNotEmpty && place.imageUrl.startsWith('http')) {
      // 비동기로 다운로드 (결과를 기다리지 않음)
      _downloadBrandIcon(place.imageUrl).then((path) {
        if (path != null) {
          debugPrint('[MapView] ✅ 브랜드 아이콘 다운로드 완료 (캐시됨): $path');
        }
      }).catchError((e) {
        debugPrint('[MapView] 브랜드 아이콘 다운로드 실패 (무시): $e');
      });
      debugPrint('[MapView] 브랜드 아이콘 다운로드 시작: ${place.imageUrl}');
    }
    
    // 선택 매장 또는 추천 매장에 따라 적절한 마커 경로 사용
    final markerPath = isRecommended 
        ? _getRecommendedMarkerImagePath(zoneInfo)
        : _getSelectedMarkerImagePath(zoneInfo);
    
    debugPrint('[MapView] 마커 이미지 경로: $markerPath');
    debugPrint('[MapView] 마커 크기: ${(_markerWidth * widthMultiplier).toInt()}x${(_markerHeight * heightMultiplier).toInt()}');
    debugPrint('[MapView] isRecommended: $isRecommended, zoneInfo: ${zoneInfo?.crowdingLevel ?? "null"}');
    
    try {
      final kImage = KImage.fromAsset(
        markerPath,
        (_markerWidth * widthMultiplier).toInt(),
        (_markerHeight * heightMultiplier).toInt(),
      );
      debugPrint('[MapView] ✅ KImage 생성 성공: $markerPath');
      return kImage;
    } catch (e, stackTrace) {
      debugPrint('[MapView] ❌ KImage 생성 실패: $e');
      debugPrint('[MapView] 스택 트레이스: $stackTrace');
      // 에러 발생 시 기본 마커 사용 (fallback)
      final fallbackPath = isRecommended
          ? 'assets/icons/marker_green.png'
          : 'assets/icons/marker_selected_green.png';
      debugPrint('[MapView] Fallback 마커 사용: $fallbackPath');
      return KImage.fromAsset(
        fallbackPath,
        (_markerWidth * widthMultiplier).toInt(),
        (_markerHeight * heightMultiplier).toInt(),
      );
    }
  }

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
    
    // recommendedPlaces 변경 감지 개선: null 체크 및 리스트 내용 비교
    bool recommendedPlacesChanged = false;
    if (widget.recommendedPlaces == null && oldWidget.recommendedPlaces == null) {
      recommendedPlacesChanged = false;
    } else if (widget.recommendedPlaces == null || oldWidget.recommendedPlaces == null) {
      recommendedPlacesChanged = true; // null <-> 리스트 변경
    } else {
      // 둘 다 null이 아닌 경우: 길이 또는 내용 비교
      if (widget.recommendedPlaces!.length != oldWidget.recommendedPlaces!.length) {
        recommendedPlacesChanged = true;
      } else {
        // 길이가 같아도 내용이 다를 수 있으므로 ID 비교
        final newIds = widget.recommendedPlaces!.map((p) => p.place.id).toSet();
        final oldIds = oldWidget.recommendedPlaces!.map((p) => p.place.id).toSet();
        recommendedPlacesChanged = !newIds.containsAll(oldIds) || !oldIds.containsAll(newIds);
      }
    }
    
    // zoneInfo나 selectedPlace, recommendedPlaces가 변경되면 POI 업데이트 및 카메라 이동
    if (widget.zoneInfo != oldWidget.zoneInfo ||
        widget.selectedPlace?.id != oldWidget.selectedPlace?.id ||
        recommendedPlacesChanged) {
      debugPrint('[MapView] didUpdateWidget: 변경 감지됨');
      debugPrint('[MapView] - zoneInfo 변경: ${widget.zoneInfo != oldWidget.zoneInfo}');
      debugPrint('[MapView] - selectedPlace 변경: ${widget.selectedPlace?.id != oldWidget.selectedPlace?.id}');
      debugPrint('[MapView] - recommendedPlaces 변경: $recommendedPlacesChanged');
      debugPrint('[MapView] - recommendedPlaces 개수: ${widget.recommendedPlaces?.length ?? 0}');
      
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
      // POI 추가 순서: 추천 장소 먼저, 선택 매장 나중에 (선택 매장이 위에 표시되도록)
      _updateRecommendedPlacesPoi().then((_) {
        // 추천 장소 POI 추가 완료 후 선택 매장 POI 추가
        return _updateSelectedPlacePoi();
      }).catchError((e) {
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
        debugPrint('[MapView] recommendedPlaces: ${widget.recommendedPlaces?.length ?? 0}개');

        // 지도 준비 완료 후 카메라 이동 및 POI 추가
        _moveCameraToMarker();
        debugPrint('[MapView] POI 추가 시작');
        // POI 추가 순서: 추천 장소 먼저, 선택 매장 나중에 (선택 매장이 위에 표시되도록)
        _updateRecommendedPlacesPoi().then((_) {
          // 추천 장소 POI 추가 완료 후 선택 매장 POI 추가
          return _updateSelectedPlacePoi();
        }).catchError((e) {
          debugPrint('[MapView] POI 업데이트 에러: $e');
        });
        // 지도 준비 완료 후 현재 위치를 가져와서 POI 추가
        _loadInitialUserLocation().catchError((e) {
          debugPrint('[MapView] 초기 사용자 위치 로드 에러: $e');
        });
        debugPrint('[MapView] POI 추가 순서 보장 완료');
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
        // 브랜드 아이콘이 있으면 사용, 없으면 혼잡도에 따라 적절한 색상의 마커 이미지 사용
        // 원본 PNG 비율을 유지하여 찌그러짐 방지
        // 선택 매장이므로 isRecommended: false
        // 기본 크기 사용 (기본 크기가 이미 선택 매장 기준으로 설정됨)
        final markerIcon = await _createMarkerIcon(
          widget.selectedPlace,
          widget.zoneInfo,
          isRecommended: false,
        );
        
        // anchor는 KPoint 타입을 사용 (x, y = 아이콘 하단 중앙)
        // 포인터(꼬리) 기준으로 하단 중앙에 위치하도록 설정
        final poiStyle = PoiStyle(
          icon: markerIcon,
          anchor: KPoint(0.5, 1.0), // 아이콘 하단 중앙에 위치 (포인터 기준)
          applyDpScale: true,
        );
        
        final markerPath = _getSelectedMarkerImagePath(widget.zoneInfo);
        debugPrint('[MapView] PoiStyle 생성: 마커 경로=$markerPath, size=${_markerWidth.toInt()}x${_markerHeight.toInt()}, anchor=(0.5, 1.0)');
        
        // addPoi는 Future<Poi>를 반환하므로 await 필요
        // text 파라미터로 텍스트 전달
        // style 파라미터는 필수이므로 PoiStyle() 사용
        debugPrint('[MapView] POI 추가 전: position=$position, text=$poiText');
        final addedPoi = await _controller!.labelLayer.addPoi(
          position,
          text: poiText,
          style: poiStyle,
        );
        debugPrint('[MapView] POI 추가 후: addedPoi=$addedPoi');
        
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

  /// 추천 장소 POI 업데이트
  Future<void> _updateRecommendedPlacesPoi() async {
    debugPrint('[MapView] _updateRecommendedPlacesPoi 호출됨');
    debugPrint('[MapView] _isMapReady: $_isMapReady, _controller: ${_controller != null}');
    debugPrint('[MapView] recommendedPlaces: ${widget.recommendedPlaces?.length ?? 0}개');
    
    if (!_isMapReady || _controller == null) {
      debugPrint('[MapView] 추천 장소 POI 업데이트 스킵: 지도가 준비되지 않음');
      return;
    }

    // 기존 추천 장소 POI 제거
    debugPrint('[MapView] 기존 추천 장소 POI 제거 중: ${_recommendedPois.length}개');
    for (final poi in _recommendedPois) {
      try {
        await _controller!.labelLayer.removePoi(poi);
        debugPrint('[MapView] 기존 추천 장소 POI 제거 완료');
      } catch (e) {
        debugPrint('[MapView] 추천 장소 POI 제거 실패: $e');
      }
    }
    _recommendedPois.clear();

    // 추천 장소가 없으면 종료
    if (widget.recommendedPlaces == null || widget.recommendedPlaces!.isEmpty) {
      debugPrint('[MapView] 추천 장소가 없어서 POI 추가 스킵');
      return;
    }

    // 새 추천 장소 POI 추가 (최대 3개)
    final placesToShow = widget.recommendedPlaces!.take(3).toList();
    debugPrint('[MapView] 추천 장소 POI 추가 시작: ${placesToShow.length}개');
    
    for (final placeWithZone in placesToShow) {
      try {
        final place = placeWithZone.place;
        final zone = placeWithZone.zone;
        final position = LatLng(place.latitude, place.longitude);
        final crowdingLevel = zone.crowdingLevel.isNotEmpty ? zone.crowdingLevel : '여유';
        final poiText = '${place.name}\n$crowdingLevel';

        debugPrint('[MapView] 추천 장소 처리 중: ${place.name}, 위치: ${place.latitude}, ${place.longitude}, 혼잡도: $crowdingLevel');

        // 추천 장소의 실제 혼잡도에 따라 색상 결정 (API 결과 반영)
        // 추천 장소 마커 사용 (isRecommended: true)
        // 마커 크기를 선택 매장 마커 크기의 75%로 설정
        final markerIcon = await _createMarkerIcon(
          place,
          zone, // 실제 API 결과의 zoneInfo 전달
          isRecommended: true,
          widthMultiplier: 0.75, // 선택 매장 크기의 75%
          heightMultiplier: 0.75,
        );

        final poiStyle = PoiStyle(
          icon: markerIcon,
          anchor: KPoint(0.5, 1.0),
          applyDpScale: true,
        );

        final markerPath = _getRecommendedMarkerImagePath(zone);
        debugPrint('[MapView] 추천 장소 POI 추가 시도: place=${place.name}, zone=${zone.crowdingLevel}, markerPath=$markerPath, position=$position');
        
        final addedPoi = await _controller!.labelLayer.addPoi(
          position,
          text: poiText,
          style: poiStyle,
        );

        _recommendedPois.add(addedPoi);
        debugPrint('[MapView] ✅ 추천 장소 POI 추가 성공: ${place.name}, POI: $addedPoi');
      } catch (e, stackTrace) {
        debugPrint('[MapView] ❌ 추천 장소 POI 추가 실패: ${placeWithZone.place.name}');
        debugPrint('[MapView] 에러: $e');
        debugPrint('[MapView] 스택 트레이스: $stackTrace');
      }
    }
    
    debugPrint('[MapView] 추천 장소 POI 업데이트 완료: 총 ${_recommendedPois.length}개 추가됨');
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
    // 추천 매장 POI 정리
    if (_controller != null && _recommendedPois.isNotEmpty) {
      for (final poi in _recommendedPois) {
        try {
          if (poi is Future) {
            (poi as Future).then((p) {
              _controller?.labelLayer.removePoi(p);
            }).catchError((e) {
              debugPrint('[MapView] 추천 매장 POI 정리 실패: $e');
            });
          } else {
            _controller!.labelLayer.removePoi(poi);
          }
        } catch (e) {
          debugPrint('[MapView] 추천 매장 POI 정리 실패: $e');
        }
      }
      _recommendedPois.clear();
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
    // 추천 장소 POI 정리
    if (_controller != null && _recommendedPois.isNotEmpty) {
      for (final poi in _recommendedPois) {
        try {
          if (poi is Future) {
            (poi as Future).then((p) {
              _controller?.labelLayer.removePoi(p);
            }).catchError((e) {
              debugPrint('[MapView] 추천 장소 POI 정리 실패: $e');
            });
          } else {
            _controller!.labelLayer.removePoi(poi);
          }
        } catch (e) {
          debugPrint('[MapView] 추천 장소 POI 정리 실패: $e');
        }
      }
    }
    _controller = null;
    _isMapReady = false;
    _currentPoi = null;
    _userLocationPoi = null;
    _recommendedPois.clear();
    _lastUserLocationPoiPosition = null;
    _lastUserLocationUpdateTime = null;
    super.dispose();
  }
}

