import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/brand_icon_mapper.dart';
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        backgroundColor: const Color(0xFFE0E0E0), // 트랙 색상
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF616161)), // 진행 인디케이터 색상
                      ),
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
            if (_searchController.text.trim().isNotEmpty) 
              Expanded(
                child: _buildAutocompleteList(),
              ),
            // 검색어가 없을 때만 최근 검색어 표시
            if (_searchController.text.trim().isEmpty)
              Expanded(
                child: RecentKeywords(
                  keywords: controller.recentKeywords,
                  onTap: (keyword) {
                    _searchController.text = keyword;
                    controller.search(keyword);
                  },
                ),
              ),
            // 하단에 추천 장소 카드뷰 추가 (검색어가 없을 때만 표시)
            if (_searchController.text.trim().isEmpty) _buildRecommendationsSection(),
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            backgroundColor: Color(0xFFE0E0E0), // 트랙 색상
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF616161)), // 진행 인디케이터 색상
          ),
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

  Widget _buildRecommendationsSection() {
    // Case 1: API 호출 실패
    if (controller.recommendationsError != null && !controller.isRecommendationsLoading) {
      return _buildErrorCard();
    }

    // Case 2: 반경 확대 중
    if (controller.isExpandingRadius) {
      return _buildExpandingRadiusCard();
    }

    // Case 3: 로딩 중 (초기)
    if (controller.isRecommendationsLoading) {
      return _buildLoadingCard();
    }

    // Case 4: 20km까지 확대했으나 결과 없음
    if (controller.recommendedPlaces.isEmpty) {
      return _buildEmptyStateCard();
    }

    // Case 5: 결과 있음
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 덜 붐비는 곳',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                // 섹션 단위 갱신 시간 표시 (첫 번째 카드 기준)
                if (controller.recommendedPlaces.isNotEmpty &&
                    controller.recommendedPlaces.first.crowdingUpdatedAt > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _formatUpdatedAtForSection(
                          controller.recommendedPlaces.first.crowdingUpdatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // 화면 세로 크기의 25%, 최소 200px, 최대 250px
              final screenHeight = MediaQuery.of(context).size.height;
              final cardViewHeight = (screenHeight * 0.25).clamp(200.0, 250.0);
              
              return SizedBox(
                height: cardViewHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0), // 하단 패딩 12px
                  itemCount: controller.recommendedPlaces.length,
                  itemBuilder: (context, index) {
                    final place = controller.recommendedPlaces[index];
                    return _buildRecommendationCard(place);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_dissatisfied_outlined,
            size: 48,
            color: Colors.grey[400]!.withOpacity(0.9),
          ),
          const SizedBox(height: 12),
          const Text(
            '추천 정보를 불러올 수 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '네트워크 연결을 확인하고 다시 시도해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              controller.loadRecommendations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0EBEB), // 웜화이트 배경 (R240 G235 B235)
              foregroundColor: const Color(0xFF1A1A1A), // 다크 그레이 텍스트
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('다시 시도하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandingRadiusCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              backgroundColor: const Color(0xFFE0E0E0), // 트랙 색상
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF616161)), // 진행 인디케이터 색상
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            size: 16,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            '더 넓은 범위를 찾아보는 중...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            backgroundColor: Color(0xFFE0E0E0), // 트랙 색상
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF616161)), // 진행 인디케이터 색상
          ),
          const SizedBox(height: 16),
          Text(
            '이 근처에서 지금 덜 붐비는 곳을 찾고 있어요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline,
            size: 48,
            color: Colors.grey[400]!.withOpacity(0.9),
          ),
          const SizedBox(height: 12),
          const Text(
            '지금은 모든 곳이 붐비네요!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '주변 20km 내에 여유로운 매장을 찾지 못했어요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '• 시간대를 바꿔보시겠어요?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• 조금 후에 다시 확인해보세요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: 알림 받기 기능 구현
                  },
                  child: const Text('알림 받기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 검색 조건 변경 기능 구현
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('검색 조건 변경'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Place place) {
    // 혼잡도에 따른 색상 결정
    final crowdingLevel = place.crowdingLevel.isNotEmpty ? place.crowdingLevel : '여유';
    final badgeConfig = _getBadgeConfig(crowdingLevel);
    
    // 카테고리에서 브랜드 또는 성격 키워드 추출
    final categoryKeyword = _extractCategoryKeyword(place.category);

    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // 그림자 연하게
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.resultMap,
              arguments: place,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: 매장명 + 혼잡도 배지 (오른쪽 inline)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 혼잡도 배지 (작게, 보조 신호)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeConfig['bg'],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        crowdingLevel,
                        style: TextStyle(
                          fontSize: 10,
                          color: badgeConfig['text'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Line 2: 도보 시간/거리
                Row(
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatDistance(place.distanceM),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Line 3: 카테고리 키워드 (있는 경우만)
                if (categoryKeyword.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    categoryKeyword,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 카테고리에서 브랜드 또는 성격 키워드 추출
  /// category_name 형식: "음식점 > 카페 > 커피전문점 > 커피에반하다"
  /// - 마지막 토큰이 고유명사면 브랜드로 간주
  /// - 중간 토큰에서 성격 키워드 추출 (커피전문점, 무인카페, 테마카페 등)
  String _extractCategoryKeyword(String category) {
    if (category.isEmpty) return '';
    
    // ">" 또는 ">"로 분리된 토큰 추출
    final tokens = category.split(RegExp(r'\s*[>|]\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    if (tokens.isEmpty) return '';
    
    // 마지막 토큰이 브랜드일 가능성 체크 (고유명사 패턴)
    final lastToken = tokens.last;
    // 브랜드 패턴: 한글+영문 조합, 특정 브랜드명 패턴 등
    if (_isBrandName(lastToken)) {
      return lastToken;
    }
    
    // 중간 토큰에서 성격 키워드 추출
    for (final token in tokens) {
      final lowerToken = token.toLowerCase();
      
      // 성격 키워드 매핑
      if (lowerToken.contains('커피전문점') || lowerToken.contains('커피숍')) {
        return '커피전문점';
      } else if (lowerToken.contains('무인') || lowerToken.contains('셀프')) {
        return '무인카페';
      } else if (lowerToken.contains('테마')) {
        return '테마카페';
      } else if (lowerToken.contains('로스터리') || lowerToken.contains('로스팅')) {
        return '로스터리';
      } else if (lowerToken.contains('베이커리')) {
        return '베이커리';
      } else if (lowerToken.contains('프랜차이즈') || lowerToken.contains('체인')) {
        return '프랜차이즈';
      }
    }
    
    // 기본적으로 '카페'는 표시하지 않음 (요구사항: 모든 카드를 '카페'로 통합 표기하지 말 것)
    return '';
  }
  
  /// 토큰이 브랜드명인지 판단 (고유명사 패턴)
  bool _isBrandName(String token) {
    if (token.isEmpty) return false;
    
    // 브랜드명 패턴:
    // 1. 영문 포함 (예: "스타벅스", "메가MGC커피")
    // 2. 특정 브랜드명 리스트에 포함
    // 3. 일반적인 카테고리명이 아닌 경우
    
    final commonCategoryNames = [
      '카페', '커피', '음식점', '커피전문점', '테마카페', '무인카페',
      '로스터리', '베이커리', '프랜차이즈', '체인', '전문점'
    ];
    
    // 일반 카테고리명이면 브랜드 아님
    if (commonCategoryNames.any((name) => token.contains(name))) {
      return false;
    }
    
    // 영문 포함 또는 특정 패턴이면 브랜드로 간주
    if (RegExp(r'[A-Za-z]').hasMatch(token)) {
      return true;
    }
    
    // 토큰 길이가 짧고(2-4자) 일반 카테고리명이 아니면 브랜드 가능성
    if (token.length >= 2 && token.length <= 6) {
      return true;
    }
    
    return false;
  }

  /// 섹션용 갱신 시각 포맷팅 ("약 n분 전 기준")
  String _formatUpdatedAtForSection(int updatedAtEpoch) {
    if (updatedAtEpoch == 0) return '';
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diffSeconds = now - updatedAtEpoch;
    
    if (diffSeconds < 60) {
      return '방금 전 기준';
    } else if (diffSeconds < 3600) {
      final minutes = diffSeconds ~/ 60;
      return '약 $minutes분 전 기준';
    } else if (diffSeconds < 86400) {
      final hours = diffSeconds ~/ 3600;
      return '약 $hours시간 전 기준';
    }
    
    return '';
  }

  Map<String, Color> _getBadgeConfig(String crowdingLevel) {
    // 지도 화면의 _DesignTokens.badgeColors와 동일한 스타일
    const badgeColors = {
      '여유': {'bg': Color(0xFFC8E6C9), 'text': Color(0xFF2E7D32)}, // #2E7D32
      '보통': {'bg': Color(0xFFDCEDC8), 'text': Color(0xFF8BC34A)}, // #8BC34A (lightgreen)
      '약간 붐빔': {'bg': Color(0xFFFFF9C4), 'text': Color(0xFFFBC02D)}, // #FBC02D (yellow)
      '붐빔': {'bg': Color(0xFFFFCDD2), 'text': Color(0xFFE53935)}, // #E53935
    };
    
    return badgeColors[crowdingLevel] ?? badgeColors['여유']!;
  }

  /// Format distance with walking time calculation (지도 화면과 동일)
  String _formatDistance(double distanceM) {
    if (distanceM <= 10) {
      return '바로 옆';
    }
    
    // Walking speed: 80m/min
    final minutes = (distanceM / 80).ceil();
    
    if (minutes <= 5) {
      return '걸어서 ${minutes}분';
    }
    
    return '${distanceM.toStringAsFixed(0)}m';
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

