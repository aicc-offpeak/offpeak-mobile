import 'package:geolocator/geolocator.dart';

import 'permission.dart';

/// 공통 위치 접근 로직. 실제 위치 플러그인 연동 시 이 계층에서만 수정.
class LocationService {
  Future<LocationPermissionStatus> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.denied;
    }

    final permission = await Geolocator.checkPermission();
    return _mapPermissionStatus(permission);
  }

  Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _mapPermissionStatus(permission);
  }

  Future<LocationData> getCurrentPosition() async {
    // 위치 서비스 활성화 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // 현재 위치 가져오기
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// 위치 업데이트 스트림 반환
  /// distanceFilter: 최소 이동 거리 (미터)
  /// 실제 throttle(시간 간격)은 호출 측에서 처리
  Stream<LocationData> getPositionStream({
    int distanceFilter = 5,
  }) async* {
    // 위치 서비스 활성화 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // 위치 스트림 구독
    await for (final position in Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    )) {
      yield LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  LocationPermissionStatus _mapPermissionStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.restricted;
    }
  }
}

class LocationData {
  final double latitude;
  final double longitude;

  const LocationData({required this.latitude, required this.longitude});
}




