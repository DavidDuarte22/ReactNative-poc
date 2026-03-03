# Demo Walkthrough — React Native Brownfield PoC

**What we proved:** A React Native surface can be embedded inside an existing native app
(UIKit on iOS, Jetpack Compose on Android) with **zero React Native knowledge required
from the host app team**. The host app links a pre-built binary and calls three methods.

---

## The Big Picture

```
┌─────────────────────────────────────────────────────┐
│  ReactNativeApp/          (RN team owns this)        │
│  ├── src/App.tsx          shared JS logic            │
│  ├── ios/                 CocoaPods build → XCFramework
│  └── android/brownfield/  Gradle build → AAR library │
└─────────────────────────────────────────────────────┘
           ↓ pre-built binary (XCFramework / AAR)
┌─────────────────────────────────────────────────────┐
│  TescoUIKitApp/           (iOS team owns this)       │
│  TescoAndroidApp/         (Android team owns this)   │
│  → no CocoaPods, no Node, no RN knowledge needed     │
└─────────────────────────────────────────────────────┘
```

The host app never sees React Native. It only sees a framework/library that
exposes familiar native APIs.

---

## iOS

### 1 — Boot the RN runtime (`AppDelegate.swift`)

One line in `AppDelegate`. The host app has no idea what's inside the framework.

```swift
import tescornappbrownfield   // the XCFramework

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = CartState.shared          // start listening for events before any RN surface fires
        ReactNativeHostManager.shared.initialize()
        window?.rootViewController = UIHostingController(rootView: HomeView())
        // ...
    }
}
```

### 2 — Embed the RN surface (`HomeView.swift`)

The host app uses `ReactNativeView` (shipped inside the XCFramework) like any other SwiftUI view.
It passes `initialProps` — native data injected into the RN component as props.

```swift
ReactNativeView(
    moduleName: "TescoRNApp",
    initialProps: ["userId": "demo-user", "locale": "en-GB"]
)
```

### 3 — React to events from RN (`CartState.swift`)

When RN fires an event, the host app reacts via a typed `AnyPublisher`. No NotificationCenter
strings, no casting — just a Combine publisher the iOS team can use natively.

```swift
import tescornappbrownfield

final class CartState: ObservableObject {
    @Published private(set) var count = 0

    private init() {
        cancellable = BridgeEvents.buttonTapped   // AnyPublisher<Void, Never>
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.count += 1 }
    }
}
```

The cart badge in the SwiftUI toolbar observes `CartState` and re-renders automatically.

### What the iOS team ships

```
TescoUIKitApp.xcodeproj     ← plain Xcode project, no CocoaPods
└── Frameworks/
    ├── tescornappbrownfield.xcframework   (~16 MB device slice)
    └── hermesvm.xcframework               (~5 MB device slice)
```

A native iOS developer needs **only Xcode** to build and run the consumer app.

---

## Android

### 1 — Boot the RN runtime (`MainApplication.kt`)

Same pattern as iOS. One line, one import.

```kotlin
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.ReactNativeHostManager

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ReactNativeHostManager.shared.initialize(this)
    }
}
```

### 2 — Extend `BrownfieldActivity` (`MainActivity.kt`)

The library provides a base Activity that handles all RN lifecycle (back button,
config changes, etc.). The consumer Activity is 10 lines.

```kotlin
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.BrownfieldActivity

class MainActivity : BrownfieldActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { HomeScreen() }
    }
}
```

### 3 — Embed the RN surface (`HomeScreen.kt`)

The RN surface drops into Compose via `AndroidView`. The host passes `launchOptions`
(equivalent of iOS `initialProps`).

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
            }
        )
    }
)
```

### 4 — React to events from RN (`CartState.kt`)

The library exposes a `SharedFlow`. The ViewModel collects it — familiar Kotlin coroutine pattern.

```kotlin
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.BridgeEvents

class CartState : ViewModel() {
    private val _cartCount = MutableStateFlow(0)
    val cartCount: StateFlow<Int> = _cartCount.asStateFlow()

    init {
        viewModelScope.launch {
            BridgeEvents.buttonTapped.collect {   // SharedFlow<Unit>
                _cartCount.value++
            }
        }
    }
}
```

The cart badge in the Compose TopAppBar observes `cartCount` and re-renders automatically.

### What the Android team ships

The dependency in the host app's `build.gradle.kts`:

```kotlin
// During development — source via composite build
// In production — replace with Nexus/Artifactory artifact
implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")
```

The `settings.gradle.kts` composite build block swaps the Maven coordinate for the
source project during development. Remove it in production and point to the artifact.

---

## The Shared JS Layer (`App.tsx`)

One codebase, two platforms. The React Native component detects the platform and
uses the right bridge mechanism.

```tsx
const handleCallNative = async () => {
    if (Platform.OS === 'android') {
        sendMessage({ event: 'buttonTapped', userId })  // BrownfieldMessaging
    } else {
        await TescoNativeBridge.onButtonTapped(`Hello from RN! userId=${userId}`)  // TurboModule
    }
}
```

The native side on both platforms receives the event through their own idiomatic API
(`AnyPublisher` on iOS, `SharedFlow` on Android) — not through anything RN-specific.

---

## Demo Flow (live)

1. **Launch the app** — native shell loads (UIKit / Compose)
2. **Tap "Open React Native Screen"** (iOS) or see the RN surface inline (Android)
3. The RN surface renders — shows `userId` and `locale` injected from native as props
4. **Tap "Call Native"** in the RN surface
5. The **cart badge in the native toolbar increments** — native reacted to an RN event
6. On iOS: a native `UIAlertController` also appears

---

## Minimum Requirements for the Host App

| | iOS | Android |
|---|---|---|
| Language | Swift 5.9+ | Kotlin 2.x |
| UI framework | UIKit or SwiftUI | Views or Compose |
| Min OS | iOS 15 | API 24 (Android 7) |
| Build system | Xcode (no CocoaPods) | Gradle 8.x + AGP 8.x |
| What they add | 2 XCFrameworks | 1 AAR dependency |

---

## What is NOT in the host app

- No `node_modules`
- No `Podfile` / `pod install`
- No React Native imports
- No JS knowledge needed
- No Metro bundler
- No Expo SDK

The RN team owns all of that. The host app team ships a native binary.
