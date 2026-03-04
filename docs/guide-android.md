# Android Developer Guide

You own `TescoAndroidApp`. The RN team ships the brownfield library via `ReactNativeApp/android`. During development it's included as a Gradle composite build — no AAR copying needed. In production it will come from Nexus/Artifactory.

## Prerequisites

| Tool | Version |
|---|---|
| Android Studio | ≥ 2024.3 (Ladybug) |
| JDK | 21 (use Android Studio embedded JBR — see below) |
| Android SDK | API 36 |
| NDK | 29.x |
| Build Tools | 36.0.0 |
| Node.js | ≥ 20.19.4 (required for Gradle build scripts) |

Node must be installed before opening the project in Android Studio. Install via Homebrew:
```bash
brew install node
```

## Setup

```bash
git clone <repo>
cd ReactNativePoC/ReactNativeApp
npm install        # applies patches — required before any Android build
```

Then open `TescoAndroidApp` in Android Studio. On first open:
- Accept the "Use Embedded JDK" prompt if shown — the project is already configured for `jbr-21`
- Click **Sync Project with Gradle Files**

## Running the app

1. Start Metro in a terminal:
```bash
cd ReactNativePoC/ReactNativeApp
npm start
```

2. In Android Studio, select the `app` run configuration and press **Run**.

The first build compiles the full RN runtime (~1–2 min). Subsequent builds are incremental.

## How the integration works

`TescoAndroidApp` has zero React Native imports. The composite build wires everything:

```kotlin
// settings.gradle.kts (TescoAndroidApp)
includeBuild("../ReactNativeApp/android") {
    dependencySubstitution {
        substitute(module("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield"))
            .using(project(":brownfield"))
    }
}
```

## Consumer code

**MainApplication.kt** — boot the RN runtime once:

```kotlin
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ReactNativeHostManager.shared.initialize(this)
    }
}
```

**MainActivity.kt** — extend `BrownfieldActivity`:

```kotlin
class MainActivity : BrownfieldActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { HomeScreen() }
    }
}
```

**Embedding an RN surface** in a Compose screen:

```kotlin
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.ReactNativeViewFactory
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.RootComponent

AndroidView(
    factory = { ctx ->
        ReactNativeViewFactory.create(
            context = ctx,
            component = RootComponent.ProductsScreen,
            launchOptions = bundleOf("storeId" to "123")
        )
    }
)
```

**Reacting to events from RN** via `CartState`:

```kotlin
val cartState: CartState = viewModel()
val cartCount by cartState.cartCount.collectAsState()
```

## Android Studio JDK setup

The project is pre-configured to use Android Studio's embedded JDK (`jbr-21`) via `.idea/gradle.xml`. This is committed so no manual setup is needed.

If you see an "Invalid Gradle JDK" prompt, go to **Settings → Build, Execution, Deployment → Build Tools → Gradle** and select **Embedded JDK**.

## Node path (macOS)

Android Studio launched from the Dock or Spotlight doesn't inherit your shell PATH. The build handles this automatically — `settings.gradle` probes known Node locations (`/usr/local/bin/node`, `/opt/homebrew/bin/node`) and all Gradle plugins are patched to use the resolved path.

No manual configuration needed as long as `npm install` has been run (it applies the patches via `postinstall`).

## Production distribution

For production, remove the `includeBuild` block from `settings.gradle.kts` and depend on the published AAR:

```kotlin
// build.gradle.kts (app)
dependencies {
    implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")
}
```

Publish the AAR from `ReactNativeApp/android`:
```bash
./gradlew :brownfield:publishToMavenLocal   # local testing
./gradlew :brownfield:publish               # Nexus/Artifactory
```

## Troubleshooting

| Error | Fix |
|---|---|
| `Cannot run program "node"` | Run `npm install` in `ReactNativeApp/` then sync Gradle |
| `Invalid Gradle JDK configuration` | Select Embedded JDK in Android Studio Gradle settings |
| Build fails on first open | Do **File → Invalidate Caches → Invalidate and Restart** |
| Metro connection error on device | Ensure Metro is running (`npm start`) and device/emulator can reach your machine on port 8081 |
| `Could not resolve expo-modules-core` | The local Maven repos in `TescoAndroidApp/settings.gradle.kts` must match the installed Expo version — re-run `npm install` |
