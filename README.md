# offpeak_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 개발환경에서 빌드 및 실행 방법

────────────────────────────

1. 레포 클론
   원격 저장소를 로컬로 내려받고 프로젝트 디렉터리로 이동합니다.

git clone 레포주소
cd 레포폴더명

2. Flutter 설치 확인
   Flutter SDK가 설치되어 있는지 확인합니다.

flutter --version

3. Android 개발 환경 점검
   Android SDK, toolchain, 라이선스 상태를 확인합니다.

flutter doctor
flutter doctor --android-licenses

4. 실기기 연결 확인
   USB 디버깅이 활성화된 실기기가 인식되는지 확인합니다.

adb devices
flutter devices

5. 프로젝트 의존성 설치
   클론 직후 반드시 의존성을 설치합니다.

flutter pub get

6. 앱 실행 (실기기)
   연결된 실기기에 앱을 빌드 및 실행합니다.

flutter run

7. 코드 수정 후 반영
   실행 중에는 hot reload / restart를 사용합니다.

r
R

8. 설정·의존성 변경 후에는 앱을 종료하고 다시 실행합니다.

Ctrl + C
flutter run

9. 빌드 문제 발생 시 초기화
   캐시 문제나 빌드 오류 발생 시 사용합니다.

flutter clean
flutter pub get
flutter run

────────────────────────────
