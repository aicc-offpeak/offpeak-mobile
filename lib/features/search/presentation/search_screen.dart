import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading.dart';
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

  @override
  void initState() {
    super.initState();
    controller.loadRecent();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchBarWidget(onSubmit: controller.search),
            // 디버깅용: 지도 화면으로 이동 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.resultMap);
                },
                child: const Text('지도 화면으로 이동 (디버깅)'),
              ),
            ),
            RecentKeywords(
              keywords: controller.recentKeywords,
              onTap: controller.search,
            ),
            if (controller.isLoading) const LoadingView(),
            if (controller.error != null)
              ErrorView(message: controller.error!, onRetry: controller.loadRecent),
            Expanded(child: _buildResultList()),
          ],
        );
      },
    );
  }

  Widget _buildResultList() {
    if (controller.results.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }
    return ListView.builder(
      itemCount: controller.results.length,
      itemBuilder: (context, index) {
        final place = controller.results[index];
        return ListTile(
          title: Text(place.name),
          subtitle: Text(place.address),
          onTap: () {
            // TODO: navigate to result map with selected place as focus
          },
        );
      },
    );
  }
}

