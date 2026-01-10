import 'package:flutter/material.dart';

import '../../../core/constants/routes.dart';
import '../../../data/models/place.dart';
import '../widgets/map_view.dart';

/// Android 전용: 지도만 전체 화면으로 표시하는 베이스라인 화면.
class ResultMapScreen extends StatelessWidget {
  final Place? selectedPlace;

  const ResultMapScreen({super.key, this.selectedPlace});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼 동작을 '다시 선택'으로 처리
        Navigator.pushReplacementNamed(context, Routes.search);
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            elevation: 0,
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 지도는 전체 화면에 표시
            MapView(selectedPlace: selectedPlace),
            // 선택된 Place가 있으면 상단에 가게명과 '다시 선택' 버튼 표시
            if (selectedPlace != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selectedPlace!.name} 기준',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              Routes.search,
                            );
                          },
                          child: const Text(
                            '다시 선택',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}




