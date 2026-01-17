import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../data/models/place.dart';

/// 자동완성 상태
enum AutocompleteState {
  idle, // 초기 상태 (표시 안 함)
  inputTooShort, // 입력 부족 (< 2자)
  loading, // 로딩 중
  success, // 정상 결과
  error, // 오류 발생
  empty, // 결과 없음
}

/// 자동완성 패널 위젯
class AutocompletePanel extends StatelessWidget {
  final AutocompleteState state;
  final List<Place> results;
  final Function(Place) onPlaceTap;

  const AutocompletePanel({
    super.key,
    required this.state,
    required this.results,
    required this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (state) {
      case AutocompleteState.idle:
        return const SizedBox.shrink();
      
      case AutocompleteState.inputTooShort:
        return _buildStateMessage('두 글자 이상 입력해보세요');
      
      case AutocompleteState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF616161)),
            ),
          ),
        );
      
      case AutocompleteState.error:
        return _buildStateMessage('검색 결과를 불러오지 못했어요');
      
      case AutocompleteState.empty:
        return _buildStateMessage('검색 결과가 없습니다.\n다른 검색어를 시도해보세요.');
      
      case AutocompleteState.success:
        return _buildResultsList();
    }
  }

  Widget _buildStateMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (results.isEmpty) {
      return _buildStateMessage('검색 결과가 없습니다.\n다른 검색어를 시도해보세요.');
    }

    // 최대 5개까지만 표시
    final displayResults = results.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      itemCount: displayResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.withOpacity(0.15),
      ),
      itemBuilder: (context, index) {
        final place = displayResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          title: Text(place.name),
          onTap: () => onPlaceTap(place),
        );
      },
    );
  }
}
