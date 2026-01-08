import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'app.dart';
import 'core/constants/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Android 전용: 카카오 지도 SDK 초기화
  final appKey = dotenv.env[Env.kakaoNativeAppKey] ?? "";
  await KakaoMapSdk.instance.initialize(appKey);

  // 카카오 지도 SDK 초기화 확인: hashKey 출력
  final hashKey = await KakaoMapSdk.instance.hashKey();
  debugPrint('[KAKAO_HASH_KEY] $hashKey');

  runApp(const OffPeakApp());
}