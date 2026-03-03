# Spike Conclusions and Limitations

**Spike:** Expo Modules Brownfield Integration — Phases 1–3 validation
**Branches:** `main`, `feat/expo-modules-migration`, `spike/expo-brownfield`, `spike/android-brownfield`
**Date:** 2026-03-03
**Status:** Phase 1 partially complete — Android V7 validated, iOS V1 validated with caveats

---

## Summary in One Line Per Platform

| Platform | Status | One-line verdict |
|---|---|---|
| **React Native (shared JS)** | ✅ Working | RN 0.83.2 + Expo SDK 55 runs on both platforms with New Architecture |
| **iOS** | ✅ Working | XCFramework produced and consumed by native UIKit app with zero CocoaPods on the consumer side |
| **Android** | ✅ Working | Brownfield AAR integrates into native Compose app via Gradle composite build |

All three layers are running end-to-end. The architecture is validated as a proof of concept. The open items below are what stands between this and production.

---

## Spike Plan Validation Status (V1–V9)

| # | Validation | Platform | Status | Notes |
|---|---|---|---|---|
| **V1** | Expo Module builds in Tuist via SPM | iOS | ✅ Effectively pass | Consumer links XCFrameworks — Expo never appears in Tuist dependency graph. Tuist project.swift integration not formally tested but pattern is proven. |
| **V2** | Zero cost for unflagged users | Both | ❌ Not validated | RN runtime starts eagerly on both platforms. No profiling done. No feature flag in place. This is a Phase 1 blocker. |
| **V3** | Firebase Remote Config timing safety | Both | ❌ Not done | No Firebase in the PoC at all. |
| **V4** | Bidirectional context sharing | Both | ⚠️ Partial | Native→RN (initialProps) ✅. RN→Native (button tap) ✅. Native→RN event emission after mount ❌ — not implemented. |
| **V5** | Third-party RN lib without CocoaPods | iOS | ❌ Not done | Only first-party Expo modules tested. Most likely failure point. |
| **V6** | Expo Updates OTA delivery | Both | ❌ Not done | JS bundle is baked into XCFramework/AAR. OTA requires expo-updates to override at runtime — not validated. Kills the main Expo advantage if it fails. |
| **V7** | Android Gradle integration | Android | ✅ Done | App builds, installs, and runs. RN surface renders in Compose host. Events flow back to native. |
| **V8** | Binary size measurement | Both | ⚠️ Partial | iOS device slice measured: ~21 MB (~14–15 MB after App Store compression). Android not measured. No before/after comparison done. |
| **V9** | CI/CD pipeline | Both | ❌ Not done | Build pipelines designed (see `platform-guide.md`) but not implemented or tested in CI. |

**Phase 1 hard blockers remaining:** V2 (zero cost when flag off).

---

## React Native — Shared JS Layer

### What was proved

- **New Architecture works end-to-end.** Fabric renderer, Hermes JS engine, JSI bridgeless mode — all running on both platforms with RN 0.83.2.
- **Expo Module DSL eliminates ObjC++.** One Swift file (iOS) or one Kotlin file (Android) replaces five files of codegen C++ + ObjC++/Kotlin boilerplate. Any iOS or Android engineer can read and modify a module.
- **Platform-split bridge strategy works.** `App.tsx` uses `Platform.OS` to call a TurboModule on iOS and `BrownfieldMessaging` on Android. Clean, no leakage between platforms.
- **AppRegistry named components are the clean seam.** `'TescoRNApp'` is the only string that must match between native consumer and JS bundle. Low coupling, easy to reason about.
- **metro.config.js must use `expo/metro-config`.** Not `@react-native/metro-config`. Expo registers a virtual entry URL (`/.expo/.virtual-metro-entry`) that requires a URL rewriter only present in the Expo Metro config.

### Limitations

- **RN 0.83.2 is hard-pinned.** Expo SDK 55 targets this version exactly. RN 0.84 added a `bundleConfiguration` parameter that breaks Expo SDK 55 Swift code inside the framework template. Cannot upgrade RN without first upgrading Expo SDK. Expo SDK 56 (targeting RN 0.84+) was not released at time of writing.
- **One JS bundle, one Hermes runtime.** All RN-powered features in the app share a single JS process. Multiple product teams sharing the same bundle need a governance model for dependencies, release cadence, and native module API contracts. This becomes the dominant scaling challenge past two RN-owning teams.
- **node_modules patches are fragile (Android).** The node path resolution bug in three Expo autolinking Kotlin source files was patched manually inside `node_modules/`. These patches are wiped on every `npm install`. `patch-package` has not been configured to persist them. A new developer running `npm install` will get a broken Android build with no obvious error.
- **No OTA validated.** The JS bundle is compiled into the binary at build time (`main.jsbundle` inside the XCFramework on iOS, `index.android.bundle` in assets on Android). Expo Updates is the mechanism to override this at runtime without an app rebuild, but it has not been integrated or tested in this brownfield embedding. OTA is the primary reason to choose Expo over Bare RN.
- **No performance baseline.** The PoC bundle is trivial (< 1 MB). A production Tesco screen will include navigation, state management, network layers, and product domain logic. Cold start time and frame budget on a representative bundle size are unknown.
- **Two component names is a known confusion.** `'TescoRNApp'` (for TescoAndroidApp and iOS) and `'main'` (for the brownfield standalone test app) are both registered. The standalone test app showing up when running via Android Studio's default config has already caused confusion.

---

## iOS

### What was proved

- **XCFramework distribution works.** `npx expo-brownfield build:ios --release --scheme tescornappbrownfield` produces two XCFrameworks:
  - `tescornappbrownfield.xcframework` — RN runtime + Expo + all native modules (~16 MB device slice)
  - `hermesvm.xcframework` — Hermes JS engine (~4.6 MB device slice)
- **Consumer app has zero CocoaPods.** `TescoUIKitApp` embeds the XCFrameworks and builds with a plain `.xcodeproj`. No `pod install`, no `.xcworkspace`, no Node. A native iOS developer needs only Xcode.
- **Tuist + SPM compatible by design.** The consumer never sees Expo or RN in its dependency graph. The XCFrameworks can be referenced directly in `Project.swift` as `TargetDependency.xcframework` or wrapped in an SPM `Package.swift` as `.binaryTarget(path:)` for local use and `.binaryTarget(url:checksum:)` for production distribution.
- **Expo Module DSL works in brownfield.** `TescoNativeBridgeModule.swift` (14 lines of Swift) is the complete native module. The Expo Module DSL handles JSI binding generation automatically. No ObjC++ required.
- **Binary size is a one-time fixed cost.** Device arm64 release: ~21 MB. After App Store compression: ~14–15 MB delivered to users. This does not grow with the number of RN features added — additional screens only add JS bundle bytes, not native binary bytes.
- **Combine publishers provide clean typed API.** `BridgeEvents.buttonTapped: AnyPublisher<Void, Never>` is the entire API surface for native→consumer events. The consumer app does not need to know about NotificationCenter.

### Limitations

- **7 workarounds required to build the XCFramework.** The expo-brownfield toolchain was not designed for a hand-crafted Xcode project. The workarounds are:
  1. Manual `PBXShellScriptBuildPhase` injection into `project.pbxproj`
  2. No `use_expo_modules!` in Podfile (conflicts with our custom `ExpoModulesProvider`)
  3. Explicit `ExpoBrownfield` + `EXManifests` pod declarations
  4. `post_install` hook to inject ExpoModulesCore/JSI headers into the Expo pod
  5. `SDKROOT` + `SUPPORTED_PLATFORMS` added to framework build configs
  6. `--scheme tescornappbrownfield` must always be passed explicitly
  7. `internal import TescoNativeBridge` in framework sources to prevent swiftinterface leakage

  All workarounds are encapsulated in `Podfile` and `project.pbxproj` — the XCFramework binary itself is identical to what a clean CNG setup would produce. But they must be re-verified on each Expo SDK upgrade.

- **The `post_install` Podfile hook is the most fragile part.** It manually injects `HEADER_SEARCH_PATHS`, `OTHER_CFLAGS`, `OTHER_SWIFT_FLAGS`, and `SWIFT_INCLUDE_PATHS` into the Expo pod's build configuration. These depend on exact path conventions inside `Pods/` that can shift between Expo SDK versions. This is the most likely point of failure on an SDK upgrade.
- **CocoaPods still required on the RN team's build side.** The consumer is clean, but the team that builds the XCFramework needs CocoaPods (`pod install` is part of the build pipeline). CocoaPods trunk goes read-only in late 2026. The platform team needs a plan — either self-host the pod spec graph or migrate the build side to SPM before then.
- **`BridgeEvents.swift` requires manual project.pbxproj registration.** New Swift files added to `ios/tescornappbrownfield/` are not auto-discovered because the directory is not configured as a `PBXFileSystemSynchronizedRootGroup`. Every new file requires either a Xcode drag-and-drop or a manual pbxproj edit.
- **OTA not validated.** The `main.jsbundle` inside the XCFramework is the release-time snapshot of the JS. Expo Updates would need to intercept bundle loading at runtime and serve a newer bundle from its cache. Whether this works correctly when running from inside a pre-built XCFramework has not been tested. This is the Phase 3 V6 risk.
- **RN runtime not lazy.** `ReactNativeHostManager.shared.initialize()` is called in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` unconditionally. For V2 (zero cost when flag off), this must be moved behind the feature flag and triggered only on user tap. Not done.
- **V5 (third-party native library) not tested.** Only the first-party `TescoNativeBridge` Expo Module has been added. Any library that ships native iOS code (not pure JS) and has not published a `Package.swift` will require CocoaPods to install — potentially leaking CocoaPods into the XCFramework build pipeline in ways that aren't yet understood.
- **Formal Tuist project.swift test not done.** The pattern is proven (XCFrameworks as `TargetDependency.xcframework` in Tuist are supported and documented). But no actual `Project.swift` has been written and run with these frameworks. One hour of work to confirm.
- **`rn-brownfield-poc.md` references RN 0.84.0.** This document is from the initial PoC (pre-expo-brownfield). The current stack is 0.83.2. That document is useful for the bridge strategy comparison but the version information is stale.

---

## Android

### What was proved

- **V7 validated.** A native Jetpack Compose app (`TescoAndroidApp`) embeds an RN surface delivered via Gradle library. The app builds, installs, and runs on an Android 36 emulator.
- **Consumer app has no direct RN imports.** `TescoAndroidApp` only imports the brownfield library. One `compileOnly("com.facebook.react:react-android:0.83.2")` is the only RN-adjacent dependency, required solely for Kotlin type resolution — not a runtime dep.
- **Composite build pattern works.** During development, `includeBuild("../ReactNativeApp/android")` in `settings.gradle.kts` lets the consumer use the brownfield library as a source project. In production, remove the block and reference the Nexus/Artifactory artifact. Clean separation.
- **Bidirectional communication works.** `initialProps` flow from native to RN at mount. `BrownfieldMessaging.sendMessage` + `SharedFlow` routes events from RN back to native. The Compose `CartState` ViewModel reacts to `BridgeEvents.buttonTapped` and updates the cart badge.
- **`BrownfieldActivity` cleanly encapsulates lifecycle requirements.** `DefaultHardwareBackBtnHandler`, `onConfigurationChanged` forwarding — all handled once in the base class. Consumer `MainActivity` is 10 lines.
- **Metro dev mode works.** Cleartext HTTP, virtual-metro-entry URL rewriting, node path discovery — all resolved.

### Limitations

- **node_modules Kotlin patches wiped on `npm install` (critical).** The Expo autolinking Gradle plugins use `"node"` as a bare command in `ProcessBuilder`. On macOS, this fails when Android Studio is launched from Dock/Spotlight (minimal launchd PATH). Three files in `node_modules/expo-modules-autolinking/` were patched manually to read from `System.getProperty("node.executable")` instead. These patches disappear on every `npm install`. `patch-package` has not been set up. A new developer will hit this with no obvious explanation.
- **5 Expo local Maven repos declared manually.** Expo modules ship pre-built AARs inside their npm packages. The `expo-autolinking-settings-plugin` registers these repos only for `ReactNativeApp/android`. `TescoAndroidApp/settings.gradle.kts` must declare all 5 manually. Every new Expo module added to `package.json` that ships a `local-maven-repo` requires a new entry here. There is no automation for this.
- **NDK and build-tools versions are machine-specific overrides.** `ext.ndkVersion = "29.0.14206865"` and `ext.buildToolsVersion = "36.0.0"` in `build.gradle` were set because NDK 27 (expected by RN) was not installed and build-tools 35.0.0 (Expo plugin fallback) had a broken `aidl` binary. On a machine with the expected versions installed, these overrides should be removed.
- **Gradle 8.13 hard-pinned.** Gradle 9.0 triggers an `IBM_SEMERU` field-not-found error in the RN Gradle plugin. The `react.internal.disableJavaVersionAlignment=true` flag (needed for Gradle 9 compatibility) causes a Kotlin/Java JVM target mismatch that breaks `expo-modules-core` compilation. Gradle 8.13 is pinned until RN resolves the plugin compatibility issue.
- **RN runtime not lazy.** `ReactNativeHostManager.shared.initialize(this)` is called in `MainApplication.onCreate()` unconditionally. V2 (zero cost when flag off) requires moving this behind a feature flag and triggering it only on first user navigation to an RN screen. Not done.
- **ProGuard/R8 rules not validated.** Release builds with minification enabled have not been tested. RN/Expo class names resolved at runtime (via reflection) may be stripped. The consumer app has `isMinifyEnabled = true` in its release build type but this path was never exercised.
- **ContentProvider auto-init audit not done.** Some libraries auto-initialize via `ContentProvider` declarations in their manifests. The merged `AndroidManifest.xml` for a release build has not been audited for unwanted auto-initialization entries that would add cost for unflagged users.
- **Binary size not measured.** No before/after APK or AAB size comparison has been done. V8 is open for Android.
- **Android Studio run config confusion.** The default run configuration in `ReactNativeApp/android` launches the brownfield standalone test app (`com.parser.rnpoc.ReactNativePoC.brownfield`), not `TescoAndroidApp`. A developer opening the wrong project will see a full-screen RN app with no native shell and wonder why the demo doesn't match expectations.

---

## What to Do Next — Prioritised

### Must do before any production discussion

1. **V2 — Feature flag + lazy init (both platforms).** Wire `initialize()` behind a boolean flag on both platforms. Profile with Instruments (iOS) and Android Studio Profiler (Android) to confirm zero RN code executes when the flag is off. This is the non-negotiable gate. With 10M+ users, any regression for unflagged users is unacceptable.

2. **`patch-package` for Android node_modules patches.** Without this, the Android setup breaks silently for every developer who runs `npm install`. Three patches, 30 minutes of work to set up.

3. **V5 — Third-party native library (iOS).** Add one library with native iOS code (e.g., a commonly needed SDK) and confirm it integrates without CocoaPods leaking into the consumer. This is the most likely Phase 1 failure point.

4. **Formal Tuist project.swift test (iOS).** Write an actual `Project.swift` that references the XCFrameworks. One hour. Confirms V1 definitively.

### Important before scaling to a second team

5. **V6 — OTA (both platforms).** Add `expo-updates`, publish a JS bundle change, confirm the app picks it up without rebuild. This is Expo's primary advantage over Bare RN. If it fails in brownfield, the architecture decision needs to be revisited.

6. **V8 — Binary size measurement (Android).** Measure APK/AAB before and after adding RN. Get the number before a stakeholder asks.

7. **Expo local Maven repos automation (Android).** Script or Gradle plugin to auto-discover repos from `node_modules` instead of manual declarations in `settings.gradle.kts`.

8. **CocoaPods sunset plan (iOS build side).** CocoaPods trunk goes read-only late 2026. The consumer is already clean. The RN build pipeline is not. Decide: self-host pod specs, or front-run the SPM migration on the build side.

### Performance and operations (before A/B test)

9. **Representative bundle performance.** Build a bundle that approximates a real Tesco screen (navigation, API calls, state management). Measure cold start on a mid-range Android device and an older supported iPhone. Do this before committing to Phase 2.

10. **V9 — CI pipeline.** Implement the three pipelines described in `platform-guide.md`:
    - XCFramework build (triggers on native module changes)
    - JS test + OTA publish (triggers on `src/` changes)
    - Android AAR publish (triggers on brownfield library changes)

---

## Document Index

| Document | What it covers |
|---|---|
| `spike-conclusions.md` | **This file** — conclusions and limitations across all three sides |
| `android-brownfield-setup.md` | Android: what was achieved, prerequisites, 5-step reproduction, gotchas |
| `reproduction-guide.md` | iOS: step-by-step guide from scratch to running XCFramework |
| `expo-brownfield-spike-results.md` | iOS: 7 workarounds for the expo-brownfield XCFramework build |
| `rn-brownfield-architecture-analysis.md` | iOS: comparison of 3 approaches (CocoaPods ObjC++, CocoaPods Expo, XCFramework) |
| `rn-brownfield-poc.md` | iOS: comparison of raw TurboModules vs Expo Module DSL (note: references RN 0.84.0, now on 0.83.2) |
| `platform-guide.md` | Both: day-to-day workflow, adding screens, adding modules, CI, OTA, scaling |
| `architecture-plan.md` | iOS: early architecture decision record (pre-expo-brownfield, partially superseded) |
