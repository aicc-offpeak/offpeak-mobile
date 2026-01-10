import 'package:flutter/material.dart';

import 'core/constants/routes.dart';
import 'core/constants/theme.dart';
import 'data/models/place.dart';
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
      title: 'offpeak',
      theme: AppTheme.light,
      initialRoute: Routes.search,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.search:
            return MaterialPageRoute(
              builder: (_) => const AppScaffold(child: SearchScreen()),
            );
          case Routes.resultMap:
            final place = settings.arguments as Place?;
            return MaterialPageRoute(
              builder: (_) => ResultMapScreen(selectedPlace: place),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AppScaffold(child: SearchScreen()),
            );
        }
      },
    );
  }
}

