/// MVP에서는 메모리 캐시. 추후 로컬 DB/SharedPreferences로 교체.
class RecentStore {
  final List<String> _keywords = [];

  List<String> load() => List.unmodifiable(_keywords);

  void add(String keyword) {
    _keywords.remove(keyword);
    _keywords.insert(0, keyword);
    if (_keywords.length > 10) {
      _keywords.removeLast();
    }
  }
}




