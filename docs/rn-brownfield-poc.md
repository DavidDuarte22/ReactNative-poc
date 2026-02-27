# React Native Brownfield iOS PoC — Experience Report

**Stack:** React Native 0.84.0 · React 19.2.3 · New Architecture (bridgeless) · iOS 15+
**Context:** Embedding a React Native surface inside an existing UIKit/SwiftUI host app (Tesco brownfield model).

---

## What we built

A minimal but production-shaped brownfield integration:

```
AppDelegate.swift
  └─ UINavigationController
       └─ UIHostingController<HomeView>          SwiftUI, zero RN imports
            └─ (push) ReactViewController        UIViewController wrapping Fabric surface
                  └─ TescoRNHost                 RCTRootViewFactory (bridgeless)
                        └─ TescoNativeBridge      TurboModule — onButtonTapped → NotificationCenter
```

The JS surface receives `userId` and `locale` as `initialProperties`, renders them, and calls back into native via a TurboModule button.

---

## Part 1 — Raw TurboModules + Codegen (current `main`)

### What it involves

Defining a native module with the **New Architecture codegen pipeline**:

| File | Purpose |
|------|---------|
| `NativeTescoNativeBridge.ts` | TypeScript spec — single source of truth |
| `TescoNativeBridgeSpec.h` | C++ header generated from the spec |
| `TescoNativeBridgeSpec-generated.mm` | C++ JSI registration generated from the spec |
| `TescoNativeBridge.h` | ObjC++ module interface |
| `TescoNativeBridge.mm` | ObjC++ implementation |
| `TescoNativeBridge.podspec` | CocoaPods spec with `install_modules_dependencies` |

The codegen files are pre-generated and committed to the repo (rather than regenerated at build time) to avoid a dependency on a Codegen script phase.

### Pros

- **Officially supported by Meta** — the canonical New Architecture path, guaranteed to work with any RN version.
- **Type-safe end-to-end** — the `.ts` spec drives both the C++ interface and the TypeScript types; mismatches are caught at code-gen time, not runtime.
- **No third-party dependency** — zero extra packages, no version alignment risk.
- **Maximum performance** — direct JSI bindings with no intermediate abstraction layer.
- **Full C++ access** — enables cross-platform shared C++ logic (Android parity with the same spec).
- **Predictable upgrade path** — tied only to `react-native` itself.

### Cons

- **High ceremony for every change** — adding a method means updating the `.ts` spec, re-running codegen, and updating the ObjC++ implementation. Three files touched for one method.
- **C++ knowledge required** — understanding the generated files, fixing compilation errors in `*-generated.mm`, and knowing when to use `#include` vs `#import`.
- **Fragile build setup** — `install_modules_dependencies` in the podspec, `RCT_USE_PREBUILT_RNCORE=0`, separate pod to avoid duplicate symbol errors from `FBReactNativeSpec-generated.mm`. Each of these took non-trivial debugging.
- **ObjC++ only on iOS** — Swift cannot directly implement a TurboModule; requires an ObjC++ bridge file.
- **Committed generated files** — the codegen output in `codegen/` must be manually regenerated and re-committed whenever the spec changes. Easy to forget; hard to review in PRs.

### Hard problems encountered during this PoC

| Problem | Root cause | Fix |
|---------|-----------|-----|
| Metro `match` syntax error in `VirtualView.js` | `hermes-parser 0.32.0` doesn't enable Flow `match` expressions by default | `parserOpts: { enableExperimentalFlowMatchSyntax: true }` in `babel.config.js` |
| `NativeMicrotasksCxx could not be found` | `getTurboModule:jsInvoker:` returned `nullptr` for all C++ modules | Delegate to `DefaultTurboModules::getTurboModule(name, jsInvoker)` |
| `Could not enqueue microtask` (Hermes) | `ReactNativeFeatureFlags::enableBridgelessArchitecture()` returned `false`; Hermes creates its runtime with `.withMicrotaskQueue(false)` | `ReactNativeFeatureFlags::dangerouslyForceOverride(OSSStable)` — `override()` silently fails if any flag was read before the call |
| `No suitable URL request handler` (symbolicate) | `RCTNetworking` in bridgeless mode has no HTTP handlers via default init | Implement `getModuleInstanceFromClass:` returning `[[RCTNetworking alloc] initWithHandlersProvider:...]` |
| Duplicate ObjC class warnings | RN 0.84 prebuilt `rncore` xcframeworks conflict with debug dylibs | `ENV['RCT_USE_PREBUILT_RNCORE'] = '0'` in Podfile |
| React version mismatch | `react-native 0.84.0` ships renderer at `19.2.3`; we had pinned `react` at `19.2.4` | Pin `react` to exactly `19.2.3` |

---

## Part 2 — Expo Modules (this branch — `feat/expo-modules-migration`)

### What it involves

Replacing the entire codegen pipeline with a single Swift file and a runtime DSL from `expo-modules-core`.

```swift
import ExpoModulesCore

public class TescoNativeBridgeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("TescoNativeBridge")

    AsyncFunction("onButtonTapped") { (message: String) in
      NotificationCenter.default.post(
        name: .init("TescoNativeBridgeButtonTapped"),
        object: message
      )
    }
  }
}
```

JS side:
```ts
import { requireNativeModule } from 'expo-modules-core';
const TescoNativeBridge = requireNativeModule('TescoNativeBridge');
await TescoNativeBridge.onButtonTapped(message);
```

### Brownfield wiring

Expo Modules were designed for apps using `ExpoAppDelegate`. Integrating them into a brownfield app with a custom `RCTHost` requires explicit bootstrapping. The key insight is that `global.expo` must be installed into the JS runtime **before** the bundle is evaluated — otherwise `ExpoBridgeModule` (which expo-modules-core always registers) fires its deprecated initialisation path from the wrong thread and crashes.

The solution hooks into `RCTHostRuntimeDelegate.host:didInitializeRuntime:`, which is called on the JS thread immediately after Hermes initialises and before `_loadJSBundle:` is dispatched.

**Files added/changed:**

| File | Role |
|------|------|
| `ExpoModulesAdapter.swift` | ObjC-callable Swift class; creates `AppContext`, registers modules, installs `global.expo` |
| `TescoRNHost.mm` | Conforms to `RCTHostRuntimeDelegate`; sets `runtimeDelegate` on the host; calls `ExpoModulesAdapter` |
| `TescoNativeBridgeModule.swift` | Swift Expo Module replacing the ObjC++ TurboModule |
| `ExpoModulesProvider.swift` | Declares the module list; discovered via `NSClassFromString("ExpoModulesProvider")` |
| `TescoNativeBridge.podspec` | `s.dependency "ExpoModulesCore"` — no `install_modules_dependencies` needed |
| `Podfile` | Adds `ExpoModulesCore` and `ExpoModulesJSI` pods |
| `babel.config.js` | Inline plugin replaces `process.env.EXPO_OS` (normally done by `babel-preset-expo`) |

**Sequence:**

```
RCTHost.start()
  └─ JS thread: initializeRuntime callback
       ├─ installJSBindings
       ├─ host:didInitializeRuntime:           ← TescoRNHost receives this
       │    └─ ExpoModulesAdapter.setup()
       │         ├─ AppContext()
       │         ├─ registerNativeModules()     ← finds ExpoModulesProvider via NSClassFromString
       │         ├─ setHostWrapper()
       │         └─ JavaScriptActor.assumeIsolated { appContext._runtime = runtime }
       │              └─ AppContext._runtime.didSet → prepareRuntime()
       │                   └─ global.expo = coreObject  ← installed before bundle loads
       └─ _loadJSBundle:
            └─ evaluateJavaScript()
                 └─ NativeModules.ExpoModulesCore (lazy)
                      └─ ExpoBridgeModule.maybeSetupAppContext
                           └─ global.expo exists → skip deprecated path ✓
```

### Hard problems encountered

| Problem | Root cause | Fix |
|---------|-----------|-----|
| `JavaScriptActor precondition failed` + `Expo is being initialized from the deprecated ExpoBridgeModule` | `host:didInitializeRuntime:` was never called — `_factory.reactHost` was `nil` when we set `runtimeDelegate` because `createReactHost:` returns the host without storing it in `factory.reactHost` | Capture the return value and assign: `RCTHost *host = [_factory createReactHost:nil]; _factory.reactHost = host; host.runtimeDelegate = self;` |
| `process.env.EXPO_OS is not defined` | `@react-native/babel-preset` doesn't replace this env var at build time (only `babel-preset-expo` does) | Inline Babel visitor in `babel.config.js` that replaces `process.env.EXPO_OS` with `'ios'` |
| `Call must be made on main thread` on alert presentation | `TescoNativeBridgeModule.AsyncFunction` posts the notification from a background thread; old ObjC++ module used to dispatch to main before posting | Wrap `UIAlertController` presentation in `DispatchQueue.main.async` in `ReactViewController` |

### Pros

- **Dramatically less boilerplate** — one Swift file replaces five files (spec, two generated C++ files, ObjC++ header, ObjC++ implementation).
- **Pure Swift** — no ObjC++, no `#include`, no C++ knowledge needed. Any iOS engineer can read and modify the module.
- **No codegen step** — adding a method is one line of Swift. No spec update, no regeneration, no committed generated files.
- **Runtime DSL** — the `definition()` body is Swift; you get autocomplete, compiler checks, and refactoring tools in Xcode for free.
- **Supports events, views, and constants** — the `ModuleDefinition` DSL covers `Events`, `Property`, `View`, `OnCreate`/`OnDestroy` lifecycle — a full module authoring surface.
- **Scales well** — adding the 10th method has the same effort as the first.
- **Bridgeless / New Architecture** — `expo-modules-core` has supported bridgeless since SDK 51 (RN 0.74).

### Cons

- **Version alignment risk with RN 0.84** — Expo SDK 55 officially targets RN 0.83. SDK 56 (targeting 0.84) is not yet released. `expo-modules-core` uses `"react-native": "*"` so it installs, but native compilation against RN 0.84 headers is officially untested.
- **Extra dependency** — `expo-modules-core` adds ~5 MB to the binary and introduces a third-party in the critical path of every native call.
- **Requires `use_expo_modules!` in Podfile** — scans `node_modules` for all `expo-*` packages; minor build-time overhead.
- **No TypeScript spec** — type definitions for the JS side must be written manually as a plain `.d.ts` wrapper. There is no single source of truth that enforces parity between Swift and TypeScript.
- **No C++ module support** — if you need a shared C++ implementation for Android parity, Expo Modules cannot host it; you'd mix approaches.
- **Slower raw JSI throughput** — the abstraction adds a thin overhead vs direct codegen bindings. Negligible for UI-driven calls, relevant for high-frequency data streams.
- **Expo infrastructure in a non-Expo app** — `requireNativeModule` is an Expo primitive. Teams unfamiliar with Expo may find this surprising in a "pure" RN brownfield.

---

## Comparison summary

| | Raw TurboModules | Expo Modules |
|---|---|---|
| **Languages** | TypeScript spec + ObjC++ | Swift only |
| **Files per module** | 5–6 | 1 |
| **Adding a method** | Edit spec → codegen → edit ObjC++ | Edit one Swift file |
| **C++ required** | Yes (build errors, generated files) | No |
| **Type safety** | End-to-end (spec drives everything) | Manual TS wrapper |
| **New Architecture** | ✅ (canonical) | ✅ (SDK 51+) |
| **RN 0.84 status** | ✅ fully supported | ⚠️ compiles but officially SDK 56 |
| **Third-party dep** | None | `expo-modules-core` |
| **Binary size impact** | Minimal | ~5 MB |
| **Upgrade risk** | Low (tied only to RN) | Medium (tied to Expo SDK cycle) |
| **Best for** | Stable, performance-critical, C++ shared logic | Rapid iteration, Swift-first teams |

---

## Recommendation

**Short term (PoC / MVP):** Expo Modules. The productivity gain is large, the module surface is small, and the RN 0.84 header risk is low given the `"*"` peer dep.

**Long term (production at scale):** Revisit when SDK 56 ships with official RN 0.84 support. If Android parity or C++ shared logic becomes a requirement, raw TurboModules remain the right tool for those specific modules. Both approaches can coexist — nothing prevents having one Expo Module and one codegen TurboModule in the same app.

**The one thing to do regardless of approach:** keep the native module interface thin. Whether the binding is Swift DSL or ObjC++ codegen, business logic belongs in Swift/Kotlin classes, not in the module definition itself. The module is a bridge, not an implementation.
