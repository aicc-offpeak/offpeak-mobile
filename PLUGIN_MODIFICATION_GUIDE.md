# KakaoMap SDK 플러그인 수정 가이드

## 개요
동심원 가이드 기능을 구현하기 위해 `kakao_map_sdk` 플러그인의 Android 코드를 수정해야 합니다.

## 수정 방법

### 옵션 1: 플러그인 포크 (권장)
1. `kakao_map_sdk` 플러그인을 GitHub에서 포크
2. 수정 후 로컬 패키지로 사용

### 옵션 2: 로컬 패키지로 복사
1. 플러그인 코드를 프로젝트 내부로 복사
2. `pubspec.yaml`에서 로컬 경로로 참조

### 옵션 3: Pub Cache 직접 수정 (임시)
⚠️ **주의**: pub cache의 파일을 직접 수정하면 `flutter pub get` 시 덮어씌워집니다.

## 수정할 파일

### 1. `KakaoMapController.kt`
위치: `android/src/main/kotlin/kr/yhs/flutter_kakao_maps/controller/KakaoMapController.kt`

**추가할 내용:**

```kotlin
// 클래스 멤버 변수 추가 (onMapReady 메서드 근처)
private var userRingsExtension: KakaoMapUserRingsExtension? = null

// onMapReady 메서드 수정
override fun onMapReady(kakaoMap: KakaoMap) {
    this.kakaoMap = kakaoMap
    this.overlayController = OverlayController(overlayChannel, kakaoMap)
    
    // 동심원 가이드 초기화
    userRingsExtension = KakaoMapUserRingsExtension(kakaoMap)
    userRingsExtension?.initialize()
    
    channel.invokeMethod("onMapReady", null)
}

// dispose 메서드 수정
fun dispose() {
    userRingsExtension?.dispose()
    channel.setMethodCallHandler(null)
    overlayChannel.setMethodCallHandler(null)
}
```

### 2. `KakaoMapControllerHandler.kt`
위치: `android/src/main/kotlin/kr/yhs/flutter_kakao_maps/controller/KakaoMapControllerHandler.kt`

**추가할 내용:**

```kotlin
// handle 메서드의 when 절에 추가
"updateUserRings" -> {
    val arguments = call.arguments?.asMap<Any?>()
    val latitude = arguments?.get("latitude")?.asDouble() ?: 0.0
    val longitude = arguments?.get("longitude")?.asDouble() ?: 0.0
    val zoomLevel = arguments?.get("zoomLevel")?.asDouble() ?: 16.0
    updateUserRings(LatLng.from(latitude, longitude), zoomLevel, result::success)
}
"updateZoomLevel" -> {
    val arguments = call.arguments?.asMap<Any?>()
    val zoomLevel = arguments?.get("zoomLevel")?.asDouble() ?: 16.0
    updateZoomLevel(zoomLevel, result::success)
}
"hideAllRings" -> hideAllRings(result::success)
"disposeUserRings" -> disposeUserRings(result::success)

// 인터페이스에 메서드 추가
fun updateUserRings(center: LatLng, zoomLevel: Double, onSuccess: (Any?) -> Unit)
fun updateZoomLevel(zoomLevel: Double, onSuccess: (Any?) -> Unit)
fun hideAllRings(onSuccess: (Any?) -> Unit)
fun disposeUserRings(onSuccess: (Any?) -> Unit)
```

### 3. `KakaoMapController.kt`에 메서드 구현 추가

```kotlin
// Handler 구현
override fun updateUserRings(center: LatLng, zoomLevel: Double, onSuccess: (Any?) -> Unit) {
    userRingsExtension?.updateUserRings(center, zoomLevel)
    onSuccess(null)
}

override fun updateZoomLevel(zoomLevel: Double, onSuccess: (Any?) -> Unit) {
    userRingsExtension?.updateRingVisibilityByZoom(zoomLevel)
    onSuccess(null)
}

override fun hideAllRings(onSuccess: (Any?) -> Unit) {
    userRingsExtension?.hideAllRings()
    onSuccess(null)
}

override fun disposeUserRings(onSuccess: (Any?) -> Unit) {
    userRingsExtension?.dispose()
    userRingsExtension = null
    onSuccess(null)
}
```

### 4. `KakaoMapUserRingsExtension.kt` 파일 추가
프로젝트의 `android/app/src/main/kotlin/com/example/offpeak_mobile/` 디렉토리에 이미 생성되어 있습니다.
플러그인 코드로 복사하거나, 플러그인에서 import하여 사용하세요.

## 참고
- 플러그인 코드 위치: `C:\Users\three\AppData\Local\Pub\Cache\hosted\pub.dev\kakao_map_sdk-1.2.3\`
- 실제 구현은 플러그인 내부에서 처리되므로, Flutter에서는 `updateUserRings(lat, lng, zoom)`만 호출하면 됩니다.
