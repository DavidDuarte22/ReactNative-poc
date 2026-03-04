# Conclusions, Limitations and Next Steps

## What was proved

| | iOS | Android |
|---|---|---|
| RN embeds in an existing native app | ✅ | ✅ |
| Consumer app has zero RN imports | ✅ (XCFrameworks) | ✅ (composite build / AAR) |
| Consumer app has zero CocoaPods / no node_modules | ✅ | ✅ |
| New Architecture end-to-end (Fabric + TurboModules) | ✅ | ✅ |
| Expo Module DSL for native bridges (pure Swift / Kotlin) | ✅ | ✅ |
| Bidirectional communication (JS ↔ native events) | ✅ | ✅ |
| Tuist / SPM binary target consumption | ✅ | n/a |
| Lazy init / feature flag gating | ❌ | ❌ |
| OTA updates via EAS | ❌ | ❌ |
| Third-party RN libraries in consumer | ❌ | ❌ |
| CI/CD pipelines | ❌ | ❌ |
| Binary size baseline | ⚠️ measured (~21 MB device) | ❌ not measured |
| Performance baseline | ❌ | ❌ |

## Limitations

### Shared JS

- **RN version pin.** Locked to `0.83.2`. Upgrading requires re-validating both platform pipelines and Expo SDK compatibility.
- **Single bundle / runtime.** One Metro bundle, one Hermes instance. Multiple independent RN features sharing the same runtime is a future concern.
- **`node_modules` patches.** Three Expo Gradle plugins and one Groovy script are patched via `patch-package` because they hardcode `"node"` as the executable. These patches must be re-validated on every Expo SDK upgrade.
- **Metro config required.** `watchFolders` must include the monorepo root. Not standard Metro configuration.

### iOS

- **7 build workarounds.** The expo-brownfield iOS build pipeline requires manual `pbxproj` edits, `post_install` hooks, and `Podfile` surgery. Fragile against `expo prebuild` reruns.
- **CocoaPods on the build side.** The RN team still needs CocoaPods to compile the XCFrameworks. Only the consumer is CocoaPods-free.
- **Eager runtime.** The RN host is initialised at app launch. Feature-flagged / lazy init is not implemented.
- **Runtime not validated with Firebase.** V3 (Firebase cold-start impact) is open.
- **OTA not validated.** EAS updates work conceptually but have not been tested end-to-end.

### Android

- **`node_modules` patches.** Same concern as shared JS above — four files patched, must be verified on Expo SDK upgrade.
- **Manual Maven repo declarations.** `TescoAndroidApp/settings.gradle.kts` lists local Maven repos for Expo prebuilt modules. These must stay in sync with the installed Expo version.
- **Gradle 8.13 pin.** `TescoAndroidApp` is pinned to Gradle 8.13 due to a Gradle 9.x incompatibility with the RN Gradle plugin's `jvmToolchain(17)` call (workaround exists but not upstream).
- **NDK and build-tools overrides.** `brownfield/build.gradle.kts` pins NDK 29.x and Build Tools 36.0.0 explicitly. These must be installed locally.
- **Eager runtime.** Same as iOS — lazy init is not implemented.
- **ProGuard / R8 not validated.** Release builds with minification have not been tested.

## Hard incompatibilities (do not attempt)

| What | Why |
|---|---|
| Gradle 9.x in TescoAndroidApp | RN Gradle plugin calls `jvmToolchain(17)` using `JvmVendorSpec.IBM_SEMERU` which was renamed in Gradle 9.0 |
| Expo SDK 56+ with RN 0.83.2 | SDK 56 targets RN 0.84 — updating SDK without updating RN will break |
| SPM source dependencies for RN | Requires dynamic linking, incompatible with New Architecture C++ TurboModules |
| Multiple independent JS bundles | One Hermes runtime per process — all RN surfaces share the same bundle |
| CocoaPods-free RN build (iOS) | Not yet possible — SPM migration is on RN roadmap for 0.85+ |

## Next steps — prioritised

### Must do before Phase 1

1. **Lazy / feature-flagged init (V2).** Move `ReactNativeHostManager.shared.initialize()` behind a feature flag. This is the most important open item — without it, all users pay the RN boot cost even if they never see an RN surface.
2. **Apply `patch-package` to remaining manual workarounds.** The iOS `pbxproj` and `Podfile` patches are still manual. Automate with `patch-package` or a checked-in script so they survive `expo prebuild`.
3. **Third-party library validation (V5).** Test one realistic RN library (e.g. `react-native-reanimated` or `react-native-svg`) through the full pipeline on both platforms.
4. **Formal Tuist test.** Validate the XCFrameworks inside a real Tuist-generated project (not just `TescoUIKitApp`).

### Important before a second team integrates

5. **OTA updates (V6).** Validate EAS Updates end-to-end. Determine what can / cannot be updated OTA (JS + assets yes, native modules no).
6. **Binary size (V8).** Measure Android AAR size. Establish a size budget. Investigate whether Hermes can be shared across multiple features.
7. **Automate Expo Maven repos.** The manually declared Maven repos in `TescoAndroidApp/settings.gradle.kts` should be generated automatically from `node_modules` so they don't drift on `npm install`.
8. **CocoaPods sunset plan.** CocoaPods goes read-only in December 2026. Track RN 0.85+ SPM migration and test as soon as it's available.

### Performance

9. **Representative bundle + cold start baseline.** Measure cold start time with a realistic JS bundle (not the PoC toy app) on both platforms.
10. **CI pipelines.** Three independent pipelines: XCFramework build, JS tests + OTA publish, native consumer app build.
