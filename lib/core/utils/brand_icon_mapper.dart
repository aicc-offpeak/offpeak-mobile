import 'package:flutter/foundation.dart';

/// 브랜드명 → 로고 이미지 에셋 경로 매핑 테이블
class BrandIconMapper {
  /// 브랜드명을 에셋 경로로 변환
  /// 매핑이 없으면 null 반환
  static String? getBrandIconAsset(String? brandName) {
    if (brandName == null || brandName.isEmpty) {
      return null;
    }

    // 브랜드명 정규화 (공백 제거)
    final normalizedName = brandName.trim();

    // 브랜드명 → 에셋 경로 매핑
    // 예: "스타벅스 강남점" → "스타벅스"로 매핑
    final brandMap = _getBrandMap();

    // 정확한 매칭 시도
    if (brandMap.containsKey(normalizedName)) {
      return brandMap[normalizedName];
    }

    // 부분 매칭 시도 (예: "스타벅스 강남점" → "스타벅스")
    // 장소명에 브랜드명이 포함되어 있는지 확인
    // 긴 브랜드명부터 매칭 (예: "스타벅스커피"가 "스타벅스"보다 먼저 매칭되도록)
    final sortedEntries = brandMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    
    for (final entry in sortedEntries) {
      if (normalizedName.contains(entry.key)) {
        debugPrint('[BrandIconMapper] 매칭 성공: "$normalizedName" contains "${entry.key}" → ${entry.value}');
        return entry.value;
      }
    }
    
    debugPrint('[BrandIconMapper] 매칭 실패: "$normalizedName"에 해당하는 브랜드를 찾을 수 없음');

    return null;
  }

  /// 브랜드명 → 에셋 경로 매핑 테이블
  /// assets/brands/ 디렉토리에 브랜드 로고 이미지를 저장해야 함
  static Map<String, String> _getBrandMap() {
    return {
      // 카페/음료
      '스타벅스': 'assets/brands/starbucks.png',
      '투썸플레이스': 'assets/brands/twosome.png',
      '이디야': 'assets/brands/ediya.png',
      '커피빈': 'assets/brands/coffeebean.png',
      '할리스': 'assets/brands/hollys.png',
      '탐앤탐스': 'assets/brands/tomntoms.png',
      '메가커피': 'assets/brands/megacoffee.png',
      '컴포즈커피': 'assets/brands/compose.png',
      '빽다방': 'assets/brands/paikdabang.png',
      '카페베네': 'assets/brands/cafebene.png',
      '엔젤리너스': 'assets/brands/angelinus.png',
      '카페드롭탑': 'assets/brands/droptop.png',
      '요거프레소': 'assets/brands/yogerpresso.png',
      '공차': 'assets/brands/gongcha.png',
      '설빙': 'assets/brands/sulbing.png',
      '던킨도넛': 'assets/brands/dunkin.png',
      '던킨': 'assets/brands/dunkin.png',
      
      // 패스트푸드
      '맥도날드': 'assets/brands/mcdonalds.png',
      '버거킹': 'assets/brands/burgerking.png',
      '롯데리아': 'assets/brands/lotteria.png',
      'KFC': 'assets/brands/kfc.png',
      '서브웨이': 'assets/brands/subway.png',
      '도미노피자': 'assets/brands/dominos.png',
      '피자헛': 'assets/brands/pizzahut.png',
      '파파존스': 'assets/brands/papajohns.png',
      '맘스터치': 'assets/brands/momstouch.png',
      
      // 편의점
      'CU': 'assets/brands/cu.png',
      'GS25': 'assets/brands/gs25.png',
      '세븐일레븐': 'assets/brands/7eleven.png',
      '이마트24': 'assets/brands/emart24.png',
      '미니스톱': 'assets/brands/ministop.png',
      
      // 베이커리
      '뚜레쥬르': 'assets/brands/touslesjours.png',
      '파리바게뜨': 'assets/brands/parisbaguette.png',
      '던킨도넛': 'assets/brands/dunkin.png',
      '던킨': 'assets/brands/dunkin.png',
      '크라운베이커리': 'assets/brands/crown.png',
      '뽀또': 'assets/brands/bbot.png',
      
      // 치킨
      'BBQ': 'assets/brands/bbq.png',
      '교촌치킨': 'assets/brands/kyochon.png',
      'BHC': 'assets/brands/bhc.png',
      '처갓집': 'assets/brands/cheogajip.png',
      '네네치킨': 'assets/brands/nene.png',
      '굽네치킨': 'assets/brands/goobne.png',
      '맘스터치': 'assets/brands/momstouch.png',
      '페리카나': 'assets/brands/pericana.png',
      '호식이두마리치킨': 'assets/brands/hosigi.png',
      
      // 기타
      '올리브영': 'assets/brands/oliveyoung.png',
      '이마트': 'assets/brands/emart.png',
      '롯데마트': 'assets/brands/lottemart.png',
      '홈플러스': 'assets/brands/homeplus.png',
    };
  }

  /// 브랜드명에서 주요 브랜드명 추출
  /// 예: "스타벅스 강남점" → "스타벅스"
  static String? extractBrandName(String? placeName) {
    if (placeName == null || placeName.isEmpty) {
      return null;
    }

    final brandMap = _getBrandMap();
    final normalizedName = placeName.trim().toLowerCase();

    // 정확한 매칭 시도
    for (final brandKey in brandMap.keys) {
      if (normalizedName.contains(brandKey)) {
        return brandKey;
      }
    }

    return null;
  }
}
