# ReactNativePoC

Tesco iOS PoC — validating embedding a React Native module into an existing UIKit app using the **New Architecture** (Fabric renderer + TurboModules, bridgeless mode).

---

## Architecture

```
UIKit shell (AppDelegate)
  └── UINavigationController
        └── UIHostingController<HomeView>         ← SwiftUI
              │  (tap button)
              └── push
                    ReactViewController            ← UIKit (hosts Fabric surface)
                      └── TescoRNHost.createRootView()
                            └── RCTRootViewFactory (bridgeless / RCTHost)
                                  └── Fabric surface "TescoRNApp"
                                        └── JS: NativeTescoNativeBridge.onButtonTapped()
                                              └── TescoNativeBridge.mm (TurboModule)
                                                    └── NotificationCenter
                                                          └── ReactViewController → UIAlertController
```

### Layer responsibilities

| File | Type | Responsibility |
|---|---|---|
| `AppDelegate.swift` | UIKit | Window, UINavigationController root |
| `HomeView.swift` | SwiftUI | Native home screen, zero RN imports |
| `ReactNativeHostManaging.swift` | Swift protocol | Interface contract — HomeView depends on this only |
| `ReactNativeHostManager.swift` | Swift | Owns `TescoRNHost`, implements protocol |
| `TescoRNHost.h/.mm` | ObjC++ | Owns `RCTRootViewFactory` (bridgeless), implements `RCTTurboModuleManagerDelegate` |
| `ReactViewController.swift` | UIKit | Embeds Fabric surface view, observes TurboModule callbacks |
| `TescoNativeBridge.h/.mm` | ObjC++ | TurboModule: `onButtonTapped` → `NotificationCenter` |
| `NativeTescoNativeBridge.ts` | TypeScript | **Codegen spec** — source of truth for the TurboModule interface |

### Why ObjC++ (.mm files)?

`RCTTurboModuleManagerDelegate` has C++ method signatures (`std::shared_ptr`, `std::string`). These cannot be implemented in Swift or plain Objective-C. The `.mm` extension enables ObjC++ which can mix both. Swift sees only the clean `TescoRNHost.h` ObjC interface — zero C++ leaks upward.

---

## New Architecture details

| Feature | Setting |
|---|---|
| Renderer | **Fabric** (via `newArchEnabled: YES`) |
| Module system | **TurboModules** (via `turboModuleEnabled: YES`) |
| Host | **RCTHost** (via `bridgelessEnabled: YES` — no `RCTBridge` anywhere) |
| JS engine | **Hermes** |
| Codegen | Runs automatically during `pod install` from `NativeTescoNativeBridge.ts` |

---

## SPM vs CocoaPods

**Verdict: CocoaPods required for now.**

| | SPM | CocoaPods |
|---|---|---|
| RN distribution | ❌ No `Package.swift` in RN npm package | ✅ Full support |
| Codegen (TurboModules) | ❌ Driven by pod hooks, no SPM equivalent | ✅ Runs automatically |
| Hermes build phases | ❌ Set up by `react_native_post_install` hook | ✅ Automatic |
| Status | Roadmap (RN 0.80+) | Production-ready |

> **Timeline**: CocoaPods trunk goes **read-only December 2026**. Full SPM support is targeted at RN 0.80+. Plan the migration for H2 2026.

---

## Callback flow

```
JS button tap
  → NativeTescoNativeBridge.onButtonTapped("Hello…")   [TurboModule, JSI — no JSON]
    → TescoNativeBridge.mm: dispatch_async(main_queue)
      → NSNotificationCenter post "TescoNativeBridgeButtonTapped"
        → ReactViewController.handleButtonTap(_:)
          → UIAlertController.present(...)
```

---

## Setup & running

### Prerequisites

- Xcode 15+
- Node 18+ (`node --version`)
- CocoaPods (`pod --version`) — install via `gem install cocoapods` or `brew install cocoapods`
- Ruby 3.x

### First-time setup

```bash
# 1. Install JS dependencies (generates node_modules)
npm install
# or: yarn / bun install

# 2. Install pods — this also runs Codegen for TescoNativeBridge
cd ReactNativePoC && pod install && cd ..
# → generates ReactNativePoC.xcworkspace
# → generates TescoNativeBridgeSpec/ headers from NativeTescoNativeBridge.ts

# 3. Always open the WORKSPACE, not the .xcodeproj
open ReactNativePoC/ReactNativePoC.xcworkspace
```

### Running

**Terminal 1 — Metro bundler:**
```bash
npm start
```

**Terminal 2 (or Xcode):**
```bash
# Via CLI
npm run ios

# Or: build from Xcode, select a simulator, ⌘R
```

> **Important**: Metro must be running when building for a simulator in Debug mode.
> The app will crash at launch if it can't reach the bundle server.

### What you should see

1. Native home screen (SwiftUI) with a "Open React Native Screen" button
2. Tap → `UINavigationController` push animation → React Native surface appears
3. RN screen shows `userId: tesco-user-42` and `locale` from native
4. Tap "Call Native (TurboModule)" → native `UIAlertController` appears

---

## File structure

```
ReactNativePoC/
├── ReactNativePoC/                   ← Xcode source (auto-discovered, no manual pbxproj entries)
│   ├── AppDelegate.swift             ← UIKit entry, UINavigationController root
│   ├── HomeView.swift                ← SwiftUI home screen
│   ├── ReactNativeHostManaging.swift ← Protocol (HomeView's only RN dependency)
│   ├── ReactNativeHostManager.swift  ← Owns TescoRNHost
│   ├── ReactViewController.swift     ← UIViewController hosting Fabric surface
│   ├── TescoRNHost.h                 ← ObjC interface (Swift-visible)
│   ├── TescoRNHost.mm                ← ObjC++: RCTRootViewFactory, TurboModule delegate
│   ├── TescoNativeBridge.h           ← TurboModule header
│   ├── TescoNativeBridge.mm          ← ObjC++: onButtonTapped implementation
│   └── ReactNativePoC-Bridging-Header.h
├── NativeTescoNativeBridge.ts        ← Codegen spec (TypeScript source of truth)
├── index.js                          ← AppRegistry.registerComponent('TescoRNApp')
├── App.tsx                           ← Root RN component
├── metro.config.js
├── babel.config.js
├── tsconfig.json
├── package.json                      ← codegenConfig for TescoNativeBridgeSpec
├── Podfile
└── README.md
```

---

## Future work (out of scope for this PoC)

- [ ] SPM migration when RN 0.80+ ships
- [ ] New Architecture on Android
- [ ] OTA updates (EAS Update or custom CDN)
- [ ] Move RN JS to a separate repo (internal npm package)
- [ ] Hermes bytecode snapshot for faster cold start
- [ ] Shared state beyond simple callbacks (e.g. cart, auth token)
- [ ] Tuist project generation
