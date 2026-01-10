import '../../../core/network/api_result.dart';
import '../../../core/utils/logger.dart';
import '../models/place.dart';
import '../models/search_request.dart';
import '../models/search_response.dart';
import '../sources/local/recent_store.dart';
import '../sources/remote/search_api.dart';

class SearchRepository {
  SearchRepository({
    SearchApi? api,
    RecentStore? recentStore,
  })  : _api = api ?? SearchApi(),
        _recentStore = recentStore ?? RecentStore();

  final SearchApi _api;
  final RecentStore _recentStore;

  List<String> getRecentKeywords() => _recentStore.load();

  Future<ApiResult<SearchResponse>> search(SearchRequest request) async {
    _recentStore.add(request.query);
    final result = await _api.search(request);
    if (result is ApiSuccess<SearchResponse>) {
      logInfo('Search success: ${result.data.places.length} items');
    }
    return result;
  }

  /// 간단한 캐싱/필터링을 위해 모델만 반환하는 helper.
  Future<ApiResult<List<Place>>> searchPlaces(SearchRequest request) async {
    final result = await search(request);
    if (result is ApiSuccess<SearchResponse>) {
      return ApiSuccess(result.data.places);
    }
    if (result is ApiFailure<SearchResponse>) {
      return ApiFailure(result.message);
    }
    return const ApiFailure('Unknown error');
  }
}




