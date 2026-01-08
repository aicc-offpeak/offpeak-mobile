import 'package:flutter/material.dart';

import 'core/constants/routes.dart';
import 'core/constants/theme.dart';
import 'features/result_map/presentation/result_map_screen.dart';
import 'features/search/presentation/search_screen.dart';
import 'shared/widgets/app_scaffold.dart';

/// OffPeakApp sets up top-level MaterialApp and simple route table.
class OffPeakApp extends StatelessWidget {
  final bool isMobile;

  const OffPeakApp({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'boom.b',
      theme: AppTheme.light,
      initialRoute: Routes.search,
      routes: {
        Routes.search: (_) => const AppScaffold(child: SearchScreen()),
        Routes.resultMap: (_) => const AppScaffold(child: ResultMapScreen()),
      },
      builder: (context, child) {
        // Android only 타깃. 추후 플랫폼별 분기를 여기에 추가 가능.
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

