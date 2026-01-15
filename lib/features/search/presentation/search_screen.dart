import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../data/models/place.dart';
import '../state/search_controller.dart' as search;
import '../widgets/recent_keywords.dart';
import '../widgets/search_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = search.SearchController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.loadRecent();
    controller.initializeLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    controller.search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 검색창과 디버그 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '가게 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 디버그 버튼
                  IconButton(
                    icon: Icon(
                      Icons.bug_report,
                      color: controller.useDebugMode ? Colors.orange : Colors.grey,
                    ),
                    onPressed: () => _showDebugDialog(context),
                    tooltip: '디버그 모드',
                  ),
                ],
              ),
            ),
            // 위치 정보 로딩 중일 때 표시
            if (controller.isLocationLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '위치 정보를 가져오는 중...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            // 검색창 바로 아래 자동완성 리스트 (검색어가 있을 때만 표시)
            if (_searchController.text.trim().isNotEmpty) _buildAutocompleteList(),
            // 검색어가 없을 때만 최근 검색어 표시
            if (_searchController.text.trim().isEmpty)
              RecentKeywords(
                keywords: controller.recentKeywords,
                onTap: (keyword) {
                  _searchController.text = keyword;
                  controller.search(keyword);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildAutocompleteList() {
    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (controller.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Text(
              '검색 중 오류가 발생했습니다',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              controller.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (controller.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
          child: Text('검색 결과가 없습니다.\n다른 검색어를 시도해보세요.'),
        ),
      );
    }

    // 최대 5개까지만 표시
    final displayResults = controller.results.take(5).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: displayResults.length,
        itemBuilder: (context, index) {
          final place = displayResults[index];
          return ListTile(
            title: Text(place.name),
            subtitle: Row(
              children: [
                if (place.category.isNotEmpty) ...[
                  Text(
                    place.category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${place.distanceM.toStringAsFixed(0)}m',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                Routes.resultMap,
                arguments: place,
              );
            },
          );
        },
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    final crowdingLevels = ['여유', '보통', '약간 붐빔', '붐빔'];
    String? selectedLevel = controller.debugCrowdingLevel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('디버그 모드 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 실제 API 사용 / 고정값 강제 선택
              Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: controller.useDebugMode,
                    onChanged: (value) {
                      if (value != null) {
                        if (!value) {
                          controller.setDebugCrowdingLevel(null);
                        }
                        controller.toggleDebugMode();
                        setDialogState(() {});
                      }
                    },
                  ),
                  const Text('실제 API 값 사용'),
                ],
              ),
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: controller.useDebugMode,
                    onChanged: (value) {
                      if (value != null && value) {
                        controller.toggleDebugMode();
                        if (selectedLevel == null) {
                          selectedLevel = '여유';
                          controller.setDebugCrowdingLevel(selectedLevel);
                        }
                        setDialogState(() {});
                      }
                    },
                  ),
                  const Text('고정값으로 강제'),
                ],
              ),
              const SizedBox(height: 16),
              // 고정값 선택 (디버그 모드가 활성화된 경우만)
              if (controller.useDebugMode) ...[
                const Text(
                  '혼잡도 고정값 선택:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...crowdingLevels.map((level) => RadioListTile<String>(
                      title: Text(level),
                      value: level,
                      groupValue: selectedLevel,
                      onChanged: (value) {
                        if (value != null) {
                          selectedLevel = value;
                          controller.setDebugCrowdingLevel(value);
                          setDialogState(() {});
                        }
                      },
                    )),
                const SizedBox(height: 8),
                Text(
                  '※ 붐빔/약간 붐빔 선택 시 추천 매장 API는 호출됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}

