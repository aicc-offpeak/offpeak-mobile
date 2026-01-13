import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/place.dart';
import '../../../data/models/search_request.dart';
import '../../../data/repositories/search_repository.dart';

class SearchController extends ChangeNotifier {
  SearchController({
    SearchRepository? repository,
    LocationService? locationService,
  })  : _repository = repository ?? SearchRepository(),
        _locationService = locationService ?? LocationService();

  final SearchRepository _repository;
  final LocationService _locationService;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 350));

  List<Place> results = [];
  List<String> recentKeywords = [];
  bool isLoading = false;
  String? error;
  LocationData? _cachedLocation;

  void loadRecent() {
    recentKeywords = _repository.getRecentKeywords();
    notifyListeners();
  }

  /// 화면 진입 시 1회 호출하여 위치를 캐시
  Future<void> initializeLocation() async {
    if (_cachedLocation == null) {
      _cachedLocation = await _locationService.getCurrentPosition();
    }
  }

  /// 디버깅용: 즉시 검색 수행 (debounce 없이)
  Future<List<Place>> searchImmediate(String keyword) async {
    if (_cachedLocation == null) {
      await initializeLocation();
    }

    final request = SearchRequest(
      query: keyword.trim(),
      lat: _cachedLocation!.latitude,
      lng: _cachedLocation!.longitude,
      size: 5,
      radiusM: 3000,
      // scope 기본값 'all' 사용, category_scope 기본값 'food_cafe' 사용
    );
    final res = await _repository.searchPlaces(request);
    switch (res) {
      case ApiSuccess<List<Place>>(data: final data):
        return data;
      case ApiFailure<List<Place>>(message: final message):
        logError('Search failed', message);
        return [];
      default:
        return [];
    }
  }

  void search(String keyword) {
    if (keyword.trim().isEmpty) {
      results = [];
      isLoading = false;
      error = null;
      notifyListeners();
      return;
    }

    _debouncer.run(() async {
      if (_cachedLocation == null) {
        await initializeLocation();
      }

      isLoading = true;
      error = null;
      notifyListeners();

      final request = SearchRequest(
        query: keyword.trim(),
        lat: _cachedLocation!.latitude,
        lng: _cachedLocation!.longitude,
        size: 5,
        radiusM: 3000,
        // scope 기본값 'all' 사용, category_scope 기본값 'food_cafe' 사용
      );
      final res = await _repository.searchPlaces(request);
      switch (res) {
        case ApiSuccess<List<Place>>(data: final data):
          results = data;
        case ApiFailure<List<Place>>(message: final message):
          error = message;
          logError('Search failed', message);
        default:
      }
      isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}




