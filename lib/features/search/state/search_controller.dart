import 'package:flutter/foundation.dart';

import '../../../core/network/api_result.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/place.dart';
import '../../../data/models/search_request.dart';
import '../../../data/repositories/search_repository.dart';

class SearchController extends ChangeNotifier {
  SearchController({SearchRepository? repository})
      : _repository = repository ?? SearchRepository();

  final SearchRepository _repository;
  final Debouncer _debouncer = Debouncer();

  List<Place> results = [];
  List<String> recentKeywords = [];
  bool isLoading = false;
  String? error;

  void loadRecent() {
    recentKeywords = _repository.getRecentKeywords();
    notifyListeners();
  }

  void search(String keyword) {
    _debouncer.run(() async {
      isLoading = true;
      error = null;
      notifyListeners();

      final request = SearchRequest(keyword: keyword);
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




