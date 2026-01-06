import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (isMobile) {
    await KakaoMapSdk.instance.initialize(dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? "");
  }

  runApp(MyApp(isMobile: isMobile));
}

class MyApp extends StatelessWidget {
  final bool isMobile;
  const MyApp({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: isMobile ? const MobileHome() : const DesktopHome(),
    );
  }
}

class DesktopHome extends StatelessWidget {
  const DesktopHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Windows에서는 지도 대신 UI/통신만 개발합니다.\nAndroid 기기 연결 시 카카오맵 사용",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class MobileHome extends StatelessWidget {
  const MobileHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: KakaoMap(
        option: KakaoMapOption(
          position: LatLng(37.4810, 126.8826),
          zoomLevel: 16,
        ),
      ),
    );
  }
}
