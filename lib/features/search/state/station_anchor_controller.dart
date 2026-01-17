import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/permission.dart';
import '../../../data/repositories/station_anchor_repository.dart';

/// 역 앵커 문구를 관리하는 Controller
class StationAnchorController extends ChangeNotifier {
  StationAnchorController({
    LocationService? locationService,
    StationAnchorRepository? repository,
  })  : _locationService = locationService ?? LocationService(),
        _repository = repository ?? StationAnchorRepository();

  final LocationService _locationService;
  final StationAnchorRepository _repository;

  String? _stationName;
  bool _hasLocation = false;
  bool _isLoading = false;
  LocationPermissionStatus? _permissionStatus;

  String? get stationName => _stationName;
  bool get hasLocation => _hasLocation;
  bool get isLoading => _isLoading;
  LocationPermissionStatus? get permissionStatus => _permissionStatus;

  /// 위치를 가져와서 근처 역을 조회
  Future<void> fetchNearestStation() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 위치 권한 및 서비스 상태 확인
      _permissionStatus = await _locationService.checkPermission();

      if (_permissionStatus != LocationPermissionStatus.granted) {
        _hasLocation = false;
        _stationName = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 현재 위치 가져오기
      final location = await _locationService.getCurrentPosition();
      _hasLocation = true;

      // 근처 역 조회
      _stationName = await _repository.fetchNearestStationName(
        location.latitude,
        location.longitude,
      );
    } catch (e) {
      print('[StationAnchorController] Error: $e');
      _hasLocation = false;
      _stationName = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 위치 권한 요청 및 역 재조회
  Future<void> requestLocationAndFetch() async {
    try {
      // 위치 권한 요청
      _permissionStatus = await _locationService.requestPermission();
      
      if (_permissionStatus == LocationPermissionStatus.granted) {
        await fetchNearestStation();
      } else {
        _hasLocation = false;
        _stationName = null;
        notifyListeners();
      }
    } catch (e) {
      print('[StationAnchorController] Request location error: $e');
      _hasLocation = false;
      _stationName = null;
      notifyListeners();
    }
  }
}
