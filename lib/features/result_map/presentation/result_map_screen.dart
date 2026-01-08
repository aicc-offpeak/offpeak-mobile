import 'package:flutter/material.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading.dart';
import '../state/result_map_controller.dart';
import '../widgets/map_view.dart';
import '../widgets/place_list_sheet.dart';

class ResultMapScreen extends StatefulWidget {
  const ResultMapScreen({super.key});

  @override
  State<ResultMapScreen> createState() => _ResultMapScreenState();
}

class _ResultMapScreenState extends State<ResultMapScreen> {
  final controller = ResultMapController();

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
        return Stack(
          children: [
            const MapView(),
            if (controller.isLoading)
              const Positioned.fill(child: IgnorePointer(child: LoadingView())),
            if (controller.error != null)
              Positioned(
                top: 48,
                left: 16,
                right: 16,
                child: ErrorView(
                  message: controller.error!,
                  onRetry: () => controller.searchAround(''),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: PlaceListSheet(
                places: controller.places,
                onSelect: controller.focus,
              ),
            ),
          ],
        );
      },
    );
  }
}




