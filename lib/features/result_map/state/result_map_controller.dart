import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/place.dart';
import '../../../data/models/search_request.dart';
import '../../../data/repositories/search_repository.dart';

class ResultMapController extends ChangeNotifier {
  ResultMapController({
    SearchRepository? repository,
    LocationService? locationService,
  })  : _repository = repository ?? SearchRepository(),
        _locationService = locationService ?? LocationService();

  final SearchRepository _repository;
  final LocationService _locationService;

  List<Place> places = [];
  bool isLoading = false;
  String? error;
  Place? focused;

  Future<void> searchAround(String keyword) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final location = await _locationService.getCurrentPosition();
    final request = SearchRequest(
      keyword: keyword,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    final result = await _repository.searchPlaces(request);
    switch (result) {
      case ApiSuccess<List<Place>>():
        places = result.data;
      case ApiFailure<List<Place>>():
        error = result.message;
      default:
    }
    isLoading = false;
    notifyListeners();
  }

  void focus(Place place) {
    focused = place;
    notifyListeners();
  }
}




