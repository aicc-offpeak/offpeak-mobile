import 'permission.dart';

/// 공통 위치 접근 로직. 실제 위치 플러그인 연동 시 이 계층에서만 수정.
class LocationService {
  Future<LocationPermissionStatus> checkPermission() async {
    // TODO: use geolocator or permission_handler
    return LocationPermissionStatus.denied;
  }

  Future<LocationPermissionStatus> requestPermission() async {
    // TODO: prompt user for permission
    return LocationPermissionStatus.granted;
  }

  Future<LocationData> getCurrentPosition() async {
    // TODO: return real GPS coordinate
    return const LocationData(latitude: 37.4810, longitude: 126.8826);
  }
}

class LocationData {
  final double latitude;
  final double longitude;

  const LocationData({required this.latitude, required this.longitude});
}




