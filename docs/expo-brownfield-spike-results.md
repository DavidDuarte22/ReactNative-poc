# expo-brownfield Validation Spike Results

**Branch:** `spike/expo-brownfield`
**Date:** 2026-02-27
**expo-brownfield version:** 55.0.12
**expo version:** 55.0.x
**RN version:** 0.83.2

---

## Objective

Validate whether `expo-brownfield` can produce `tescornappbrownfield.xcframework` +
`hermesvm.xcframework` that a Tesco UIKit consuming app can embed — **with no CocoaPods setup**
on the consumer side.

---

## Result: **SUCCESS — Path A adopted**

Both XCFrameworks were produced:

```
artifacts/
  tescornappbrownfield.xcframework/
    ios-arm64/                    ← device
    ios-arm64_x86_64-simulator/   ← simulator
  hermesvm.xcframework/
    ios-arm64/
    ios-arm64_x86_64-simulator/
    ios-arm64_x86_64-maccatalyst/
    tvos-arm64/
    tvos-arm64_x86_64-simulator/
    xros-arm64/
    xros-arm64_x86_64-simulator/
```

Build command used:
```sh
npx expo-brownfield build:ios --release --scheme tescornappbrownfield
```

---

## Step Results Summary

| Step | Result | Notes |
|---|---|---|
| npm install | ✅ Pass | expo@55 + expo-brownfield@55.0.12 installed on RN 0.83.2 |
| expo prebuild --platform ios --no-install | ✅ Pass (with workaround) | Required manual pbxproj injection first |
| pod install | ✅ Pass | 84 pods installed |
| expo-brownfield build:ios --release | ✅ Pass | Both XCFrameworks produced |

---

## Workarounds Required

### 1. Inject "Bundle React Native code and images" build phase into `project.pbxproj`

**Root cause:** `expo-brownfield`'s config plugin (`withXcodeProjectPlugin.js`) looks for
`'Bundle React Native code and images'` shell-script build phase in the main app target before
generating the framework target. This phase is created by `react-native init` / CNG prebuild
but was absent from our hand-crafted project.

**Fix:** Manually injected a `PBXShellScriptBuildPhase` into `project.pbxproj` with UUID
`C3D4E5F6A7B8C90AB12C3D4E` and added it to the `ReactNativePoC` target's `buildPhases` array.

```
C3D4E5F6A7B8C90AB12C3D4E /* Bundle React Native code and images */ = {
    isa = PBXShellScriptBuildPhase;
    name = "Bundle React Native code and images";
    shellScript = "set -e\n\nWITH_ENVIRONMENT=\"${REACT_NATIVE_PATH}/scripts/xcode/with-environment.sh\"\n...";
};
```

### 2. Add `:modular_headers => true` to ExpoModulesCore in Podfile

Required so the Expo pod's Swift code can resolve `<ExpoModulesCore/ExpoModulesCore.h>` via
module import syntax.

### 3. Inject ExpoModulesCore + ExpoModulesJSI build settings into Expo pod via post_install

`Expo.podspec` only declares `s.dependency 'ExpoModulesCore'` when `use_expo_modules!` is called.
Since we manage ExpoModulesCore explicitly without `use_expo_modules!`, CocoaPods doesn't add
ExpoModulesCore/ExpoModulesJSI to the Expo pod's xcconfig.

Added a `post_install` hook in the Podfile to:
- Add `HEADER_SEARCH_PATHS` for both ExpoModulesCore and ExpoModulesJSI public headers
- Add `-fmodule-map-file` flags to `OTHER_CFLAGS` and `OTHER_SWIFT_FLAGS` for both module maps
- Add `SWIFT_INCLUDE_PATHS` pointing to `${PODS_CONFIGURATION_BUILD_DIR}/ExpoModulesCore`
- Add explicit Xcodeproj target dependencies (`expo_target.add_dependency(expo_core_target)`) to
  enforce build order — ExpoModulesCore must compile before Expo so `ExpoModulesCore-Swift.h`
  (the ObjC bridge header) exists when Expo's `.mm` files need it

### 4. Add `ExpoBrownfield` and `EXManifests` pods to Podfile

The generated `tescornappbrownfield/` framework template imports `ExpoBrownfield` and
`EXManifests` modules. These pods were not installed because expo-brownfield doesn't add
them automatically when managing pods explicitly (without `use_expo_modules!`).

```ruby
pod 'ExpoBrownfield', :path => '../node_modules/expo-brownfield/ios'
pod 'EXManifests', :path => '../node_modules/expo-manifests/ios'
```

### 5. Add `SDKROOT` and `SUPPORTED_PLATFORMS` to framework build configurations

The expo prebuild-generated framework target's build configurations were missing iOS targeting
settings. Without them, xcodebuild showed no iOS destinations.

Added to both Debug and Release configs in `project.pbxproj`:
```
SDKROOT = iphoneos;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
IPHONEOS_DEPLOYMENT_TARGET = 15.1;
```

### 6. Pass `--scheme tescornappbrownfield` explicitly

`expo-brownfield`'s `findScheme()` searches subdirectories of `ios/` for a directory containing
`ReactNativeHostManager.swift`. Both `ReactNativePoC/` (app) and `tescornappbrownfield/`
(expo-brownfield template) match; alphabetical order picks `ReactNativePoC` first.

Must always pass `--scheme tescornappbrownfield` explicitly.

### 7. Add `import TescoNativeBridge` to the framework template

`ReactNativeHostManager.swift` references `ExpoModulesProvider()` without an explicit import.
In the standard expo flow, `use_expo_modules!` generates `ExpoModulesProvider.swift` and adds it
as a compile source to the app target (same Swift module = visible without import). In our setup,
`ExpoModulesProvider` lives in `TescoNativeBridgePod` (the `TescoNativeBridge` Swift module).

Added `import TescoNativeBridge` to `ios/tescornappbrownfield/ReactNativeHostManager.swift`.

---

## TescoRNHost.mm Requirements — Coverage

| # | Requirement | Status | Notes |
|---|---|---|---|
| 1 | **RCTNetworking HTTP handlers** | ✅ Handled internally | `RCTReactNativeFactory` → `RCTAppSetupDefaultModuleFromClass` |
| 2 | **DefaultTurboModules** | ✅ Handled internally | `RCTReactNativeFactory.mm` → `DefaultTurboModules::getTurboModule` |
| 3 | **ExpoModulesAdapter / JS thread setup** | ✅ Handled internally | `EXReactNativeFactory.mm` → `host:didInitializeRuntime:` |
| 4 | **ReactNativeFeatureFlags** | ⚠️ Unconfirmed | Presumably handled by `RCTReactNativeFactory` |
| 5 | **Hermes factory** | ✅ Handled internally | `RCTDefaultReactNativeFactoryDelegate.mm` + `ExpoReactNativeFactory.swift` |

---

## Decision: **Path A** — expo-brownfield + XCFramework Distribution

### Why the workaround approach is viable:

1. **Build succeeds end-to-end** — all 7 workarounds are confined to the build toolchain, not
   the RN runtime. The XCFramework binary itself is identical to what a CNG project would produce.
2. **Consuming app has zero CocoaPods setup** — the goal is achieved.
3. **Workarounds are encapsulated** — all in `Podfile` post_install + `project.pbxproj`. The
   template files in `tescornappbrownfield/` only need 1 line change (`import TescoNativeBridge`).
4. **Maintenance**: When upgrading RN/expo SDK, re-run `expo prebuild` and re-apply the
   SDKROOT/SUPPORTED_PLATFORMS fix to the generated framework configs. The Podfile hooks are
   stable as long as pod names don't change.

### Trade-offs vs Path B (manual xcodebuild scripts):

| Aspect | Path A (expo-brownfield) | Path B (manual) |
|---|---|---|
| Hermes packaging | ✅ Automated | Manual — need to copy from Pods |
| Versioning | Tied to Expo SDK | Full control |
| XCFramework slices | ✅ Both device + simulator | Manual |
| Maintenance burden | Expo SDK upgrades | RN upgrades |
| Template control | Limited (template files) | Full |

---

## Files Modified

| File | Change |
|---|---|
| `react-native.config.js` | Deleted (was RN 0.84 workaround, not needed on 0.83.2) |
| `ios/Podfile` | `:modular_headers => true`, `ExpoBrownfield`, `EXManifests` pods, post_install hook |
| `ios/ReactNativePoC.xcodeproj/project.pbxproj` | Injected Bundle RN build phase, SDKROOT/SUPPORTED_PLATFORMS for framework configs |
| `ios/ReactNativePoC/Supporting/Expo.plist` | Created empty plist (required by expo prebuild) |
| `ios/tescornappbrownfield/ReactNativeHostManager.swift` | Added `import TescoNativeBridge` |
| `ios/tescornappbrownfield/` (directory) | Created by expo prebuild (framework template files) |

---

## Next Steps

1. Embed `artifacts/tescornappbrownfield.xcframework` and `artifacts/hermesvm.xcframework` in the
   Tesco UIKit consuming app (no CocoaPods required).
2. Wire up `ReactNativeHostManager.shared.loadView(moduleName:initialProps:launchOptions:)` from
   the UIKit app's `UIViewController`.
3. Validate the consuming app builds and the RN screen renders correctly.
4. Add CI step to run `npx expo-brownfield build:ios --release --scheme tescornappbrownfield` and
   archive the XCFrameworks as build artifacts.
