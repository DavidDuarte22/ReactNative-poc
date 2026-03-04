# iOS Developer Guide

You own `TescoUIKitApp`. The RN team ships you two XCFrameworks — you embed them and call a single initialiser. No CocoaPods, no `node_modules`, no Metro.

## Prerequisites

- Xcode ≥ 16.0
- No CocoaPods, no Node required

## What you get

```
TescoUIKitApp/
  Frameworks/
    tescornappbrownfield.xcframework   ← your app code + Expo modules
    hermesvm.xcframework               ← Hermes JS engine
```

The frameworks are committed to the repo. When the RN team ships a new build, they update these files and you just pull and rebuild.

## Setup

```bash
git clone <repo>
open TescoUIKitApp/TescoUIKitApp.xcodeproj
# Build and run — no extra steps
```

## Initialising the RN runtime

In `AppDelegate.swift`, boot the runtime once at launch:

```swift
import tescornappbrownfield

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = CartState.shared                      // start listening for events before any RN surface
        ReactNativeHostManager.shared.initialize()
        // ... set up window
        return true
    }
}
```

## Embedding an RN surface

```swift
import SwiftUI
import tescornappbrownfield

struct ProductsView: View {
    var body: some View {
        ReactNativeView(
            moduleName: "ProductsScreen",
            initialProps: ["storeId": "123"]
        )
    }
}
```

`moduleName` must match a component registered via `AppRegistry.registerComponent` in the JS app.

## Reacting to events from RN

The bridge publishes events via `CartState`. Subscribe using Combine:

```swift
import Combine

class HomeViewModel: ObservableObject {
    @Published var cartCount = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        CartState.shared.cartCountPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$cartCount)
    }
}
```

## Tuist / SPM integration

The XCFrameworks are binary targets — they work as first-class Tuist dependencies:

```swift
// Project.swift
.target(
    name: "TescoApp",
    dependencies: [
        .xcframework(path: "Frameworks/tescornappbrownfield.xcframework"),
        .xcframework(path: "Frameworks/hermesvm.xcframework"),
    ]
)
```

SPM binary targets (`.binaryTarget`) also work. The RN team can publish the frameworks to a binary store (S3, Artifactory) for versioned distribution.

> **Note:** CocoaPods is only required on the RN build side to compile the XCFrameworks. You never need to run `pod install` in `TescoUIKitApp`.

## Troubleshooting

| Error | Fix |
|---|---|
| `hermesc not found` | Run `pod install` in `ReactNativeApp/ios` and rebuild the XCFrameworks |
| Blank white screen | Metro is not running — start it with `npm start` in `ReactNativeApp/` |
| `BridgeEvents not found` | Rebuild the XCFramework — the `TescoNativeBridgePod` source changed |
| PCH mismatch / module rebuild errors | Clean build folder (`Cmd+Shift+K`) and rebuild |
