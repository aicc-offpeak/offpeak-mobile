# KakaoMap SDK 플러그인 패치 가이드

## 중요: 플러그인 코드 직접 수정 필요

플러그인 코드를 직접 수정해야 합니다. 위치:
`C:\Users\three\AppData\Local\Pub\Cache\hosted\pub.dev\kakao_map_sdk-1.2.3\android\src\main\kotlin\kr\yhs\flutter_kakao_maps\`

⚠️ **주의**: `flutter pub get` 실행 시 변경사항이 덮어씌워질 수 있습니다.

## 수정 방법

### 옵션 1: Pub Cache 직접 수정 (빠른 테스트용)
- 위치: `C:\Users\three\AppData\Local\Pub\Cache\hosted\pub.dev\kakao_map_sdk-1.2.3\`
- ⚠️ `flutter pub get` 시 덮어씌워짐

### 옵션 2: 플러그인 포크 (권장)
1. GitHub에서 `kakao_map_sdk` 플러그인 포크
2. 수정 후 `pubspec.yaml`에서 git 경로로 참조

### 옵션 3: 로컬 패키지
1. 플러그인 코드를 프로젝트 내부로 복사
2. `pubspec.yaml`에서 path로 참조

## 수정할 파일들

### 1. KakaoMapController.kt

**위치**: `controller/KakaoMapController.kt`

**1-1. import 추가 (파일 상단)**
```kotlin
import com.kakao.vectormap.shape.ShapeManager
import com.kakao.vectormap.shape.ShapeLayer
import com.kakao.vectormap.shape.ShapeLayerOptions
import com.kakao.vectormap.shape.Polygon
import com.kakao.vectormap.shape.PolygonOptions
import com.kakao.vectormap.shape.PolygonStyles
import com.kakao.vectormap.shape.PolygonStylesSet
import com.kakao.vectormap.shape.DotPoints
import com.kakao.vectormap.label.VectorLayerPass
```

**1-2. 클래스 멤버 변수 추가 (line 33 근처)**
```kotlin
  public lateinit var mapView: MapView

  // 동심원 가이드 관련
  private var shapeManager: ShapeManager? = null
  private var userRingsLayer: ShapeLayer? = null
  private var ring10m: Polygon? = null
  private var ring50m: Polygon? = null
  private var ring100m: Polygon? = null
```

**1-3. onMapReady 메서드 수정 (line 219 근처)**
```kotlin
  override fun onMapReady(kakaoMap: KakaoMap) {
    this.kakaoMap = kakaoMap
    this.overlayController = OverlayController(overlayChannel, kakaoMap)
    
    // 동심원 가이드 초기화
    shapeManager = kakaoMap.shapeManager
    userRingsLayer = shapeManager?.addLayer(
      ShapeLayerOptions.from("userGuideLayer", 10001, VectorLayerPass.Default)
    )
    
    channel.invokeMethod("onMapReady", null)
  }
```

**1-4. dispose 메서드 수정 (line 255 근처)**
```kotlin
  fun dispose() {
    // 동심원 가이드 정리
    removeAllRings()
    userRingsLayer?.let { shapeManager?.removeLayer(it) }
    userRingsLayer = null
    shapeManager = null
    
    channel.setMethodCallHandler(null)
    overlayChannel.setMethodCallHandler(null)
  }
  
  // 동심원 가이드 관련 메서드 추가
  private fun updateUserRings(center: LatLng, zoomLevel: Double) {
    val layer = userRingsLayer ?: return
    
    // 기존 링 제거
    removeAllRings()
    
    // 10m 원형 Polygon 생성 (채움, 알파 0.30)
    val circle10mOptions = PolygonOptions.from(
      DotPoints.fromCircle(center, 10.0)
    ).setStylesSet(
      PolygonStylesSet.from(
        PolygonStyles.from(android.graphics.Color.parseColor("#4D2196F3"))
          .setStrokeColor(android.graphics.Color.TRANSPARENT)
          .setStrokeWidth(0)
      )
    )
    ring10m = layer.addPolygon(circle10mOptions)
    
    // 50m 원형 Polygon 생성 (선만, 알파 0.55, 두께 2px)
    val circle50mOptions = PolygonOptions.from(
      DotPoints.fromCircle(center, 50.0)
    ).setStylesSet(
      PolygonStylesSet.from(
        PolygonStyles.from(android.graphics.Color.TRANSPARENT)
          .setStrokeColor(android.graphics.Color.parseColor("#8C2196F3"))
          .setStrokeWidth(2)
      )
    )
    ring50m = layer.addPolygon(circle50mOptions)
    
    // 100m 원형 Polygon 생성 (선만, 알파 0.35, 두께 2px)
    val circle100mOptions = PolygonOptions.from(
      DotPoints.fromCircle(center, 100.0)
    ).setStylesSet(
      PolygonStylesSet.from(
        PolygonStyles.from(android.graphics.Color.TRANSPARENT)
          .setStrokeColor(android.graphics.Color.parseColor("#592196F3"))
          .setStrokeWidth(2)
      )
    )
    ring100m = layer.addPolygon(circle100mOptions)
    
    // 줌 레벨에 따라 100m 링 show/hide
    updateRingVisibilityByZoom(zoomLevel)
  }
  
  private fun updateRingVisibilityByZoom(zoomLevel: Double) {
    val ring = ring100m ?: return
    if (zoomLevel > 15.0) {
      ring.show()
    } else {
      ring.hide()
    }
  }
  
  private fun hideAllRings() {
    ring10m?.hide()
    ring50m?.hide()
    ring100m?.hide()
  }
  
  private fun removeAllRings() {
    val layer = userRingsLayer ?: return
    ring10m?.let { layer.removePolygon(it) }
    ring50m?.let { layer.removePolygon(it) }
    ring100m?.let { layer.removePolygon(it) }
    ring10m = null
    ring50m = null
    ring100m = null
  }
```

### 2. KakaoMapControllerHandler.kt

**위치**: `controller/KakaoMapControllerHandler.kt`

**2-1. handle 메서드의 when 절에 추가 (line 104 근처, "finish" 다음)**
```kotlin
      "finish" -> finish(result::success)
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
      else -> result.notImplemented()
```

**2-2. 인터페이스에 메서드 시그니처 추가 (line 157 근처)**
```kotlin
  fun finish(onSuccess: (Any?) -> Unit)
  
  fun updateUserRings(center: LatLng, zoomLevel: Double, onSuccess: (Any?) -> Unit)
  fun updateZoomLevel(zoomLevel: Double, onSuccess: (Any?) -> Unit)
  fun hideAllRings(onSuccess: (Any?) -> Unit)
  fun disposeUserRings(onSuccess: (Any?) -> Unit)
}
```

**2-3. KakaoMapController.kt에 메서드 구현 추가**
```kotlin
  override fun updateUserRings(center: LatLng, zoomLevel: Double, onSuccess: (Any?) -> Unit) {
    updateUserRings(center, zoomLevel)
    onSuccess(null)
  }
  
  override fun updateZoomLevel(zoomLevel: Double, onSuccess: (Any?) -> Unit) {
    updateRingVisibilityByZoom(zoomLevel)
    onSuccess(null)
  }
  
  override fun hideAllRings(onSuccess: (Any?) -> Unit) {
    hideAllRings()
    onSuccess(null)
  }
  
  override fun disposeUserRings(onSuccess: (Any?) -> Unit) {
    removeAllRings()
    userRingsLayer?.let { shapeManager?.removeLayer(it) }
    userRingsLayer = null
    shapeManager = null
    onSuccess(null)
  }
```

## Flutter 코드

Flutter 코드는 이미 준비되어 있습니다. `map_view.dart`에서 다음 메서드들을 호출합니다:
- `updateUserRings(latitude, longitude, zoomLevel)`
- `updateZoomLevel(zoomLevel)`
- `hideAllRings()`
- `disposeUserRings()`

## 테스트

플러그인 코드 수정 후:
1. Android 프로젝트를 Clean & Rebuild
2. 앱 실행하여 동심원 가이드 확인
