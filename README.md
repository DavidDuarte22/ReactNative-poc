# React Native Brownfield PoC

A proof-of-concept embedding React Native into existing native apps (iOS UIKit + Android Jetpack Compose) using the New Architecture (Fabric + TurboModules, Hermes, bridgeless mode).

## What was built

| | |
|---|---|
| **ReactNativeApp** | The RN project. Owns all JS, Expo Modules, and native bridge code. Produces a distributable artifact for each platform. |
| **TescoUIKitApp** | Native iOS consumer. Embeds RN as two XCFrameworks. Zero CocoaPods, zero RN imports. |
| **TescoAndroidApp** | Native Android consumer. Embeds RN as an AAR via Gradle composite build. Zero RN imports. |

```
ReactNativeApp  ─────────────────────────────────────────────────────
  ├── src/                  JS screens and bridge interfaces
  ├── ios/                  CocoaPods + expo-brownfield build pipeline
  │     └── builds ──► tescornappbrownfield.xcframework
  │                    hermesvm.xcframework
  └── android/              Gradle composite build
        └── brownfield/ ──► AAR (composite dependency)

TescoUIKitApp               embeds the two XCFrameworks
TescoAndroidApp             includes ReactNativeApp/android as composite build
```

## Status

| Validation | Result |
|---|---|
| iOS XCFramework distribution (zero CocoaPods in consumer) | ✅ |
| Android AAR distribution (zero RN imports in consumer) | ✅ |
| Bidirectional communication (JS ↔ native) | ✅ |
| New Architecture end-to-end (Fabric + TurboModules) | ✅ |
| Expo Module DSL for native bridges | ✅ |
| Lazy init / feature-flagged boot | ❌ not validated |
| OTA updates (EAS) | ❌ not validated |
| Third-party RN libraries in consumer | ❌ not validated |
| CI/CD pipelines | ❌ not validated |

## Guides

- [React Native developers](docs/guide-react-native.md) — JS development, adding screens and modules, building artifacts
- [iOS developers](docs/guide-ios.md) — consuming the XCFrameworks, Tuist/SPM integration
- [Android developers](docs/guide-android.md) — consuming the AAR, Android Studio setup
- [Conclusions, limitations and next steps](docs/conclusions.md)
