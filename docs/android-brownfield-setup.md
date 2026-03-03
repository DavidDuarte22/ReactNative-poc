# Android Brownfield — What Was Built and How to Reproduce It

## What Was Achieved

**Branch:** `spike/android-brownfield`
**Validation target:** V7 — Expo Module builds in Gradle and runs inside a native Android app

We proved that a native **Jetpack Compose** app can embed a React Native surface delivered
via a Gradle library, with bidirectional communication between native and JS — with zero
React Native imports in the consumer app's own code.

Specifically:

- A Compose host app (`TescoAndroidApp`) embeds an RN surface inside a native screen
- The consumer app has **no direct React Native or Expo imports** — it only depends on the
  brownfield library AAR
- The RN surface receives structured data from native at mount (`userId`, `locale`)
- Tapping a button in the RN surface sends an event to native via `BrownfieldMessaging`
- The native Compose UI reacts to the event and updates the cart badge in real time
- The app fetches the JS bundle from Metro in debug builds and loads a bundled
  `index.android.bundle` in release — no special setup needed for either mode

---

## The Demo

When the app runs you see:

```
┌──────────────────────────────────────┐
│  Tesco                      🛒 [n]   │  ← Native Compose top bar, badge starts at 0
├──────────────────────────────────────┤
│  Tap the button inside the React ... │  ← Native description (Compose Text)
├──────────────────────────────────────┤
│                                      │
│       React Native Surface           │  ← React Native (Fabric, New Architecture)
│  ┌──────────────────────────────┐    │
│  │ userId   android-user-001   │    │  ← initialProps passed from native at mount
│  │ locale   en-GB              │    │
│  └──────────────────────────────┘    │
│                                      │
│         [ Call Native ]              │  ← JS button
│                                      │
│  Tap → BrownfieldMessaging →         │
│  SharedFlow → Compose badge          │  ← hint text
│                                      │
└──────────────────────────────────────┘
```

Tapping **Call Native**:

1. JS calls `sendMessage({ event: 'buttonTapped', userId })`
2. `BrownfieldMessaging` dispatches the event to the native side
3. `BridgeEvents.buttonTapped` SharedFlow emits
4. `CartState` ViewModel (native Kotlin) increments `cartCount`
5. The cart badge in the native top bar re-renders: 🛒 **[1]**, **[2]**, **[3]**…

This proves the full round-trip: native data into RN at mount, RN event back to native,
native UI reacts — all without the consumer app knowing anything about React Native.

---

## Architecture

Two separate Android projects in the monorepo, connected by a Gradle composite build:

```
ReactNativePoC/
├── ReactNativeApp/
│   ├── src/App.tsx                     ← JS/TS source (shared iOS + Android)
│   ├── index.js                        ← AppRegistry: 'TescoRNApp' + 'main'
│   └── android/
│       ├── brownfield/                 ← THE LIBRARY (AAR)
│       │   └── src/.../
│       │       ├── ReactNativeHostManager.kt    ← owns the RN runtime (singleton)
│       │       ├── BrownfieldActivity.kt        ← base Activity with RN lifecycle
│       │       ├── ReactNativeViewFactory.kt    ← creates the RN surface view
│       │       ├── ReactNativeFragment.kt       ← Fragment wrapper for the surface
│       │       └── BridgeEvents.kt             ← SharedFlow for RN→native events
│       ├── app/                        ← Standalone test app (not TescoAndroidApp)
│       └── build.gradle + settings.gradle + gradle.properties
│
└── TescoAndroidApp/                    ← THE CONSUMER (Compose native app)
    └── app/src/main/java/.../
        ├── MainApplication.kt          ← initialises RN host on app start
        ├── MainActivity.kt             ← extends BrownfieldActivity, sets HomeScreen
        ├── HomeScreen.kt               ← Compose UI: top bar + RN surface
        └── CartState.kt                ← ViewModel: collects BridgeEvents → cartCount
```

**In development:** `TescoAndroidApp/settings.gradle.kts` includes `ReactNativeApp/android`
as a Gradle composite build. Gradle substitutes the Maven artifact
`com.parser.rnpoc.ReactNativePoC.brownfield:brownfield` with the `:brownfield` source
project — no publishing step needed.

**In production:** Publish the AAR to Nexus/Artifactory. Remove the composite build block
from `settings.gradle.kts` and the consumer depends on a regular Maven artifact.

### Key files in TescoAndroidApp (the consumer)

| File | What it does |
|---|---|
| `settings.gradle.kts` | Composite build + Expo local Maven repos |
| `app/build.gradle.kts` | Dependencies: brownfield library, appcompat, compileOnly react-android |
| `MainApplication.kt` | Calls `ReactNativeHostManager.shared.initialize(this)` |
| `MainActivity.kt` | Extends `BrownfieldActivity`, renders `HomeScreen()` |
| `HomeScreen.kt` | Compose UI: native top bar + `AndroidView` embedding RN surface |
| `CartState.kt` | ViewModel: collects `BridgeEvents.buttonTapped` → `cartCount` StateFlow |
| `app/src/debug/AndroidManifest.xml` | Permits cleartext HTTP to Metro (debug only) |
| `app/src/debug/res/xml/network_security_config.xml` | Whitelists `10.0.2.2` + `localhost` |

---

## Prerequisites

Install these before attempting to reproduce:

| Tool | Required version | Notes |
|---|---|---|
| Android Studio | Meerkat (2024.3) or later | Any recent version works |
| JDK | 17 | Use Android Studio's bundled JBR or Gradle's managed JDK |
| Android SDK | API 36 | Install via SDK Manager |
| NDK | **29.x** | Install via SDK Manager → NDK. Version 29.0.14206865 used here. |
| Build Tools | **36.0.0** | Install via SDK Manager. Version 35.0.0 has a broken `aidl`. |
| Node.js | 18+ | Must be at `/opt/homebrew/bin/node` or `/usr/local/bin/node` |
| npm | 9+ | Comes with Node |
| Gradle | 8.13 | Managed by the wrapper — no manual install needed |
| Android emulator | API 36 | AVD name used: `Medium_Phone_API_36.1` |

> **NDK note:** RN 0.83 expects NDK 27. If you have 27 installed, remove the
> `ext.ndkVersion` line from `ReactNativeApp/android/build.gradle`. If you only have 29
> (like this machine), the override keeps it.

> **Build Tools note:** If you have a clean install with 35.0.0, the aidl binary may be
> missing. Install 36.0.0 via SDK Manager and keep the override.

---

## Reproduce in 5 Steps

### Step 0 — Clone and checkout

```bash
git clone git@github.com:DavidDuarte22/ReactNative-poc.git
cd ReactNativePoC
git checkout spike/android-brownfield
```

### Step 1 — Install JS dependencies

```bash
cd ReactNativeApp
npm install
```

> If you see Gradle build failures about `node` not being found later, confirm that
> `which node` returns `/opt/homebrew/bin/node` or `/usr/local/bin/node`. The Gradle
> settings script probes those paths automatically.

### Step 2 — Start Metro

In a dedicated terminal, keep this running throughout:

```bash
cd ReactNativeApp
npx react-native start --reset-cache
```

Confirm you see:

```
Metro waiting on exp+tescornapp://expo-development-client/?url=...
```

Metro is ready. Leave it running.

### Step 3 — Start the emulator

```bash
emulator -avd Medium_Phone_API_36.1 &
```

Or launch it from Android Studio's Device Manager. Wait until the emulator fully boots
(home screen visible) before the next step.

Confirm adb sees it:

```bash
adb devices
# List of devices attached
# emulator-5554   device
```

### Step 4 — Build and install TescoAndroidApp

```bash
cd TescoAndroidApp

# If JAVA_HOME is not set, point it to Android Studio's JBR:
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

The first build downloads dependencies and takes 3–5 minutes. Subsequent builds are
incremental and much faster.

### Step 5 — Launch

```bash
adb shell am start -n com.tesco.tescoandroidapp/.MainActivity
```

You should immediately see the Tesco app open with the native top bar and the RN surface
below it. Tap **Call Native** and watch the cart badge increment.

---

## Two Apps, One Repository — Don't Get Confused

There are **two separate Android apps** in this monorepo:

| App | Package | Launched by | What it shows |
|---|---|---|---|
| **TescoAndroidApp** | `com.tesco.tescoandroidapp` | `adb shell am start -n com.tesco.tescoandroidapp/.MainActivity` | Native Compose top bar + embedded RN surface |
| **Brownfield test app** | `com.parser.rnpoc.ReactNativePoC.brownfield` | Android Studio default run config | Full-screen RN (no native shell) |

If you open `ReactNativeApp/android` in Android Studio and hit Run, you get the
**brownfield test app** (full-screen RN, userId shows "unknown"). That's the expo-brownfield
standalone test harness — useful for brownfield library development but not the demo.

To run **TescoAndroidApp** from Android Studio, open `TescoAndroidApp/` as a separate
project and use the `:app` run configuration.

---

## How the Two Projects Connect

`TescoAndroidApp/settings.gradle.kts`:

```kotlin
includeBuild("../ReactNativeApp/android") {
  dependencySubstitution {
    // In development: use the source project instead of a published artifact.
    // In production: remove this block and depend on the Nexus artifact.
    substitute(module("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield"))
      .using(project(":brownfield"))
  }
}
```

Gradle treats the brownfield library source as if it were a local Maven artifact. The
consumer app just declares:

```kotlin
implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")
```

…and Gradle redirects that to the source project via the substitution above.

---

## Consumer App Code (What an Android Dev Writes)

The consumer app has five files. All RN complexity lives in the brownfield library.

**MainApplication.kt** — initialise the RN runtime once on app start:
```kotlin
class MainApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    ReactNativeHostManager.shared.initialize(this)
    // TODO production: call this only when feature flag is ON
  }
}
```

**MainActivity.kt** — extend BrownfieldActivity, set Compose content:
```kotlin
class MainActivity : BrownfieldActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    setContent { HomeScreen() }
  }
}
```

**CartState.kt** — observe RN events in a ViewModel:
```kotlin
class CartState : ViewModel() {
  private val _cartCount = MutableStateFlow(0)
  val cartCount: StateFlow<Int> = _cartCount.asStateFlow()

  init {
    viewModelScope.launch {
      BridgeEvents.buttonTapped.collect { _cartCount.value++ }
    }
  }
}
```

**HomeScreen.kt** — embed the RN surface in Compose:
```kotlin
AndroidView(
  modifier = Modifier.fillMaxSize(),
  factory = { _ ->
    ReactNativeViewFactory.createFrameLayout(
      context = activity,
      activity = activity,
      rootComponent = RootComponent.TescoRNApp,
      launchOptions = Bundle().apply {
        putString("userId", "android-user-001")
        putString("locale", "en-GB")
      },
    )
  },
)
```

That's the entire integration surface. No RN lifecycle management, no bundle loading, no
Hermes setup — all of that is inside the brownfield library.

---

## Gotchas Reference

These are the problems encountered during the spike and their fixes. If a build fails,
check here first.

### 1. Explicit react-android / hermes-android versions

**Why it exists:** The React Native Maven BOM (which resolves `react-android` and
`hermes-android` versions) is applied only inside `ReactNativeApp/android`. When
`TescoAndroidApp` assembles its APK, those transitive deps arrive without versions and
Gradle fails.

**Fix:** Explicit versions in `brownfield/build.gradle.kts`:
```kotlin
implementation("com.facebook.react:react-android:0.83.2")
implementation("com.facebook.hermes:hermes-android:0.14.1")
```

Update both whenever `react-native` is bumped in `package.json`.

### 2. `compileOnly react-android` in TescoAndroidApp

**Why it exists:** `BrownfieldActivity` implements `DefaultHardwareBackBtnHandler` (from
`react-android`). `MainActivity` extends `BrownfieldActivity`. The Kotlin compiler needs
the full type hierarchy on the compile classpath.

`react-android` is `implementation` in brownfield (not `api`), so it's not exposed to
consumers. `TescoAndroidApp` adds `compileOnly` to satisfy the compiler without including
a duplicate runtime JAR.

```kotlin
compileOnly("com.facebook.react:react-android:0.83.2")
```

### 3. `BrownfieldActivity` must implement `DefaultHardwareBackBtnHandler`

**Why:** `ReactDelegate.onHostResume()` casts the host Activity to this interface at
runtime. Without it: `ClassCastException` on launch.

**Fix:** `BrownfieldActivity` implements it once; all consumer Activities inherit it.

### 4. `useDevSupport = BuildConfig.DEBUG`

**Why:** `ReactBuildConfig.DEBUG` (inside the pre-built `react-android` AAR) is always
`false`. Library `BuildConfig` flags are baked in at compile time and never reflect the
consumer's build variant.

**Symptom:** Debug build loads bundled assets instead of Metro — appears to work but shows
stale JS.

**Fix:** Pass the brownfield module's own flag:
```kotlin
useDevSupport = BuildConfig.DEBUG  // brownfield module's BuildConfig, not ReactBuildConfig
```

### 5. Android cleartext HTTP

**Why:** Android 9+ blocks plain HTTP. Metro serves bundles over HTTP on port 8081.
The emulator reaches the host machine at `10.0.2.2`.

**Fix:** `TescoAndroidApp/app/src/debug/` contains a debug-only manifest overlay:
- `AndroidManifest.xml` — references `@xml/network_security_config`
- `res/xml/network_security_config.xml` — permits HTTP to `10.0.2.2` and `localhost`

These files are only merged into debug APKs. Release builds are unaffected.

### 6. `expo/.virtual-metro-entry` 404

**Why:** Expo registers a virtual entry URL that must be rewritten to `index.js` before
Metro processes the request. `@react-native/metro-config` has no such rewriter.

**Symptom:** Metro log shows 404 on `/.expo/.virtual-metro-entry.bundle`.

**Fix:** `metro.config.js` uses `expo/metro-config`:
```js
const {getDefaultConfig} = require('expo/metro-config');
const {mergeConfig} = require('@react-native/metro-config');
module.exports = mergeConfig(getDefaultConfig(__dirname), config);
```

### 7. NDK and Build Tools overrides

`ReactNativeApp/android/build.gradle` sets:
```groovy
ext.ndkVersion = "29.0.14206865"    // RN expects 27; only 29 installed here
ext.buildToolsVersion = "36.0.0"    // 35.0.0 has a broken aidl binary
```

Remove or adjust these if your machine has the expected versions installed.

### 8. Gradle 8.13 (not 9.0)

**Why:** Gradle 9.0 triggers an `IBM_SEMERU` field-not-found error in the RN Gradle
plugin. Additionally, the flag `react.internal.disableJavaVersionAlignment=true` (needed
for Gradle 9 compatibility) disables `jvmToolchain(17)`, causing a Kotlin/Java JVM target
mismatch that breaks `expo-modules-core` compilation.

Gradle 8.13 works without any workarounds. Pinned in
`TescoAndroidApp/gradle/wrapper/gradle-wrapper.properties`.

### 9. Expo bundled module local Maven repos

Expo modules ship pre-built AARs inside their npm packages under `local-maven-repo/`.
The expo autolinking plugin registers these only for `ReactNativeApp/android`. The
`TescoAndroidApp` needs them too as transitive dependencies.

They are declared manually in `TescoAndroidApp/settings.gradle.kts`. If a new Expo module
is added to `package.json` that ships a `local-maven-repo`, add a new entry there.

### 10. Node path resolution (Android Studio from Dock/Spotlight)

When Android Studio is launched from the macOS Dock or Spotlight rather than a terminal,
it inherits a minimal `launchd` PATH that excludes `/opt/homebrew/bin`. Gradle subprocesses
that execute `node` directly will fail.

`ReactNativeApp/android/settings.gradle` probes known macOS paths at configuration time
and stores the result in `System.setProperty("node.executable", ...)`. Build scripts
read this property when they need to run node. If you see errors about `node` not being
found, ensure node is at `/opt/homebrew/bin/node` or `/usr/local/bin/node`.

---

## Producing and Consuming the Library (Production Path)

During development, Gradle composite builds give you live source-level changes. For
production, the library is published as an AAR to Nexus/Artifactory.

**Publish (RN team):**
```bash
cd ReactNativeApp/android
./gradlew :brownfield:publishBrownfieldReleasePublicationToMavenLocal
# Or to remote Nexus:
./gradlew :brownfield:publish
```

**Consume (Android team):**
```kotlin
// TescoAndroidApp/settings.gradle.kts — remove the composite build block, then:
// TescoAndroidApp/app/build.gradle.kts
implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.2.3")
```

---

## Version Matrix

| Package | Version |
|---|---|
| react-native | 0.83.2 |
| react | 19.2.3 |
| expo | ~55.0.0 |
| expo-brownfield | ~55.0.0 |
| expo-modules-core | ^55.0.12 |
| react-android (Maven) | 0.83.2 |
| hermes-android (Maven) | 0.14.1 |
| Gradle | 8.13 |
| AGP (Android Gradle Plugin) | 8.12.0 |
| Kotlin | 2.1.20 |
| compileSdk | 36 |
| minSdk | 24 |
| NDK | 29.0.14206865 |
| Build Tools | 36.0.0 |

expo@55 targets RN 0.83.x exactly. Do not bump `react-native` past 0.83.x without also
upgrading the expo SDK version.

---

## Known Limitations / Open Items

| Item | Status | Notes |
|---|---|---|
| RN initialises eagerly in `MainApplication.onCreate()` | Open | For production, gate behind feature flag. See `MainApplication.kt` TODO comment. |
| node_modules patches wiped by `npm install` | Open | Patches to expo autolinking Kotlin source fix node path resolution. Need `patch-package` to persist them. |
| Expo local Maven repos declared manually | Open | Must add a new entry to `settings.gradle.kts` each time a new Expo module with a `local-maven-repo` is added. |
| Binary size not measured | Open | V8 from the spike plan — no before/after numbers yet. |
| ProGuard/R8 rules for release not validated | Open | V7 item — release builds need RN/Expo classes retained. |
| ContentProvider auto-init audit | Open | V7 item — check merged `AndroidManifest.xml` for unwanted auto-init declarations. |
