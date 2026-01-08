import 'package:flutter/material.dart';

import '../widgets/map_view.dart';

/// Android 전용: 지도만 전체 화면으로 표시하는 베이스라인 화면.
class ResultMapScreen extends StatelessWidget {
  const ResultMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MapView(),
    );
  }
}




