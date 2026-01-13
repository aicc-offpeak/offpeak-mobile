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
            // 검색창
            Padding(
              padding: const EdgeInsets.all(16.0),
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
        child: Text(
          controller.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (controller.results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
          child: Text('검색 결과가 없습니다.'),
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
}

