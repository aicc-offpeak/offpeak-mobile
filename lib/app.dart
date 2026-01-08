import 'package:flutter/material.dart';

import 'core/constants/routes.dart';
import 'core/constants/theme.dart';
import 'features/result_map/presentation/result_map_screen.dart';
import 'features/search/presentation/search_screen.dart';
import 'shared/widgets/app_scaffold.dart';

/// OffPeakApp sets up top-level MaterialApp and simple route table.
/// Android 전용으로 가정.
class OffPeakApp extends StatelessWidget {
  const OffPeakApp({super.key});

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
    );
  }
}

