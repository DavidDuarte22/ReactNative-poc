# Android Brownfield Setup

How the Android side of the React Native PoC is structured and why certain decisions
were made. Read this before modifying any Gradle or Kotlin files.

---

## Architecture

Two separate Android projects coexist in the monorepo:

```
ReactNativePoC/
├── ReactNativeApp/android/      ← RN framework (brownfield library + standalone test app)
│   ├── brownfield/              ← Library module — ReactNativeHostManager, BrownfieldActivity, etc.
│   ├── app/                     ← Standalone test app (com.parser.rnpoc.ReactNativePoC.brownfield)
│   ├── build.gradle             ← Root: NDK/buildTools overrides + RN/Expo plugin classpath
│   ├── settings.gradle          ← Autolinking + brownfield Gradle plugin setup
│   └── gradle.properties        ← newArchEnabled=true, hermesEnabled=true
│
└── TescoAndroidApp/             ← Native Android consumer (com.tesco.tescoandroidapp)
    ├── app/                     ← Compose UI + embedded RN surface (HomeScreen.kt)
    ├── settings.gradle.kts      ← Composite build config + Expo local Maven repos
    └── gradle/wrapper/          ← Gradle 8.13 (pinned — see Gradle version below)
```

**In production**, the brownfield library would be published to Nexus/Artifactory and
`TescoAndroidApp` would depend on it as a regular versioned Maven artifact. During
development, Gradle composite builds let `TescoAndroidApp` consume the `:brownfield`
source project directly without publishing.

---

## Composite Build

`TescoAndroidApp/settings.gradle.kts` includes `ReactNativeApp/android` as a composite
build and maps the Maven coordinate to the source project:

```kotlin
includeBuild("../ReactNativeApp/android") {
  dependencySubstitution {
    substitute(module("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield"))
      .using(project(":brownfield"))
  }
}
```

When you're ready to switch to a published artifact, remove this block and declare:

```kotlin
implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")
```

---

## Component / Module Names

Two `AppRegistry` names are registered in `ReactNativeApp/index.js`:

| Name | Consumer |
|---|---|
| `TescoRNApp` | `TescoAndroidApp` (`HomeScreen.kt → RootComponent.TescoRNApp`) |
| `main` | Brownfield standalone test app (`ReactNativeFragment → RootComponent.Main`) |

Android Studio's default run configuration launches the **standalone test app** package
(`com.parser.rnpoc.ReactNativePoC.brownfield`), not TescoAndroidApp. Switch to the
`:app` run configuration in the `TescoAndroidApp` project to run the consumer app.

---

## Dev Workflow

```bash
# 1. Start Metro (from the RN project root)
cd ReactNativeApp
npx react-native start

# 2. Build and install TescoAndroidApp (in a second terminal)
cd TescoAndroidApp
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.tesco.tescoandroidapp/.MainActivity
```

Metro runs at `http://10.0.2.2:8081` (emulator) or `http://localhost:8081` (physical
device with `adb reverse tcp:8081 tcp:8081`).

---

## Gotchas and Decisions

### 1. Explicit react-android / hermes-android versions in brownfield

**Problem:** `com.facebook.react.rootproject` applies the React Native Maven BOM that
pins `react-android` and `hermes-android` versions. This BOM is only visible _inside_
the `ReactNativeApp/android` composite build. When `TescoAndroidApp` assembles its APK,
these transitive deps arrive with no version and Gradle fails to resolve them.

**Fix:** Declare explicit versions directly in `brownfield/build.gradle.kts`:

```kotlin
implementation("com.facebook.react:react-android:0.83.2")
implementation("com.facebook.hermes:hermes-android:0.14.1")
```

Explicit declarations take precedence over the BOM inside the included build and make
the versions visible to any external consumer.

> **Update versions here** whenever you bump `react-native` in `package.json`.

### 2. `compileOnly` react-android in TescoAndroidApp

`BrownfieldActivity` implements `DefaultHardwareBackBtnHandler` from `react-android`.
`MainActivity` extends `BrownfieldActivity`, so the Kotlin compiler needs
`DefaultHardwareBackBtnHandler` on the compile classpath.

`react-android` is declared as `implementation` (not `api`) in brownfield — meaning it
is **not** exposed to consumers' compile classpath. `TescoAndroidApp` adds it as
`compileOnly` to satisfy the compiler without duplicating the runtime JAR (which is
already included transitively):

```kotlin
compileOnly("com.facebook.react:react-android:0.83.2")
```

### 3. `BrownfieldActivity` implements `DefaultHardwareBackBtnHandler`

`ReactDelegate.onHostResume()` casts the host Activity to `DefaultHardwareBackBtnHandler`
at runtime. Any Activity that hosts a React Native surface must implement this interface.

`BrownfieldActivity` implements it so that all consumer Activities (including
`MainActivity`) inherit the implementation without boilerplate:

```kotlin
open class BrownfieldActivity : AppCompatActivity(), DefaultHardwareBackBtnHandler {
  override fun invokeDefaultOnBackPressed() {
    onBackPressedDispatcher.onBackPressed()
  }
}
```

### 4. `useDevSupport = BuildConfig.DEBUG`

`ReactBuildConfig.DEBUG` (from the react-android AAR) is **always `false`** in
pre-compiled library artifacts. Passing it to `ExpoReactHostFactory.getDefaultReactHost`
disables Metro dev mode even on debug builds, causing the app to load the bundled
`index.android.bundle` instead of fetching from Metro.

The fix is to pass `brownfield`'s own `BuildConfig.DEBUG` which is correctly set:

```kotlin
reactHost = ExpoReactHostFactory.getDefaultReactHost(
  context = application.applicationContext,
  packageList = PackageList(application).packages,
  useDevSupport = BuildConfig.DEBUG  // brownfield module's own flag, not ReactBuildConfig
)
```

### 5. Android cleartext HTTP policy

Android 9+ blocks plain HTTP by default. Metro runs over HTTP at `10.0.2.2:8081`
(emulator) / `localhost:8081` (physical device). Without an explicit exception, the app
silently falls back to the bundled assets in debug builds.

Fix: `TescoAndroidApp/app/src/debug/` contains a debug-only manifest overlay and
network security config that permit cleartext traffic to Metro hosts only:

```
TescoAndroidApp/app/src/debug/
├── AndroidManifest.xml                   ← references @xml/network_security_config
└── res/xml/network_security_config.xml   ← permits HTTP to 10.0.2.2 and localhost
```

### 6. `expo/.virtual-metro-entry` URL rewriting

Expo registers a virtual Metro entry point (`/.expo/.virtual-metro-entry`) that must be
rewritten to the real entry file (`index.js`) before Metro processes the request. This
rewriting is provided by `@expo/metro-config` via `server.rewriteRequestUrl`.

`@react-native/metro-config` has no such rewriter. Using it causes a Metro 404 on the
virtual URL and the app never loads a bundle.

Fix: `metro.config.js` uses `expo/metro-config`:

```js
const {getDefaultConfig} = require('expo/metro-config');
const {mergeConfig} = require('@react-native/metro-config');
module.exports = mergeConfig(getDefaultConfig(__dirname), config);
```

### 7. NDK and Build Tools versions

The RN Gradle plugin defaults to:
- NDK `27.0.12077973` — not installed on this machine; NDK 29 is. Override via
  `ext.ndkVersion = "29.0.14206865"` in `ReactNativeApp/android/build.gradle`.
- Build Tools `35.0.0` — installed but corrupted. Override via
  `ext.buildToolsVersion = "36.0.0"`.

> These overrides are machine-specific. Remove them if the expected versions are
> installed.

### 8. Gradle version: 8.13

`TescoAndroidApp` uses Gradle 8.13 (pinned in `gradle/wrapper/gradle-wrapper.properties`).

Gradle 9.0 was tried but required `react.internal.disableJavaVersionAlignment=true`
(to suppress an IBM SEMERU JDK check in the RN plugin). That flag disables
`jvmToolchain(17)`, causing Kotlin to pick up JDK 21 from `JAVA_HOME` while Java stays
at the AGP default (1.8) — a mismatch that breaks `expo-modules-core` compilation.

Gradle 8.13 works without this flag and with the JVM alignment intact.

### 9. Expo bundled module local Maven repos

Expo modules ship pre-built AAR artifacts inside their npm packages under
`local-maven-repo/`. The `expo-autolinking-settings-plugin` registers these repos for
`ReactNativeApp/android` only. `TescoAndroidApp` needs them too (as transitive deps
of brownfield → expo modules).

They are registered manually in `TescoAndroidApp/settings.gradle.kts`:

```kotlin
val expoNested = file("${rnModules}/expo/node_modules")
maven { url = uri("${expoNested}/expo-asset/local-maven-repo") ... }
maven { url = uri("${expoNested}/expo-file-system/local-maven-repo") ... }
// ... etc.
```

Add a new entry here whenever a new Expo module is added that ships a `local-maven-repo`.

---

## React Native version matrix

| Package | Version |
|---|---|
| react-native | 0.83.2 |
| react | 19.2.3 |
| @react-native/cli | 19.1.2 |
| expo | ~55.0.0 |
| expo-brownfield | ~55.0.0 |
| expo-modules-core | ^55.0.12 |
| react-android (Maven) | 0.83.2 |
| hermes-android (Maven) | 0.14.1 |

expo@55 targets RN 0.83.x exactly. Do not bump to RN 0.84+ without also upgrading expo.
