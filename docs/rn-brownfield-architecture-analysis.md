# React Native Brownfield — Architecture Comparison & Platform Decision Analysis

**Date:** 2026-02-28
**Branch:** `spike/expo-brownfield`
**Audience:** Platform team
**Status:** Experiment — architectures under active evaluation

---

## Approaches Explored in This PoC

Three distinct integration strategies were prototyped, each building on the previous:

| | Approach 1 | Approach 2 | Approach 3 |
|---|---|---|---|
| **Branch** | `main` | `feat/expo-modules-migration` | `spike/expo-brownfield` |
| **Native bridge** | Hand-written ObjC++ TurboModules | Expo Module DSL (Swift) | Expo Module DSL (Swift) |
| **Consumer dep. model** | CocoaPods in native app | CocoaPods in native app | XCFramework, no CocoaPods |
| **Expo** | No | Partial | Full (expo-brownfield) |
| **OTA capable** | No | No | Yes (EAS Update) |
| **SPM / Tuist compatible** | No | No | Yes |

---

## Approach 1 — CocoaPods + ObjC++ TurboModules

The initial implementation embedded RN directly: all 100+ pods installed into the native app workspace, and the `TescoNativeBridge` module was authored as ObjC++ (`.h` + `.mm` files) backed by codegen-generated C++ specs.

**What worked:** full New Architecture (Fabric, JSI bridgeless), RN rendered inside UIViewController.

**Why it does not scale for Tesco:**

The native app team — 40 iOS engineers working with Tuist and SPM — would need CocoaPods installed and a CocoaPods-managed workspace to build the app. This directly conflicts with the Tuist + SPM model. Every developer who touches the native app would need awareness of the RN dependency graph. Onboarding friction, `.xcworkspace` vs `.xcodeproj` ambiguity, and CocoaPods/SPM symbol conflicts make this a dead end.

Every new native capability requires: codegen invocation, a C++ spec file, an ObjC++ implementation, and ObjC header bridges. That is four files and two languages to expose one function. At 40 engineers, this pattern creates a high bus-factor risk — ObjC++ expertise is not uniformly distributed and is declining as the industry moves to Swift.

---

## Approach 2 — CocoaPods + Expo Modules

The bridge authoring problem was solved. `TescoNativeBridgeModule.swift` became pure Swift using the Expo Module DSL — one file, no C++, no ObjC headers:

```swift
AsyncFunction("onButtonTapped") { (message: String) in … }
```

The C++ JSI binding is auto-generated and never touched. This is the correct authoring model.

However the dependency model problem remained: CocoaPods still lives in the native app. The consumer still cannot be built with SPM/Tuist alone. This approach solved the developer experience problem but not the integration architecture problem.

---

## Approach 3 — expo-brownfield XCFramework (current)

This is the approach that satisfies both constraints simultaneously.

The RN team owns a standard Expo project. `expo-brownfield build:ios --release` produces two XCFrameworks:

```
artifacts/
  tescornappbrownfield.xcframework   ← RN runtime + Expo + all native modules
  hermesvm.xcframework               ← Hermes JS engine (isolated)
```

The Tesco native app embeds these two frameworks. That is the entire integration surface. No CocoaPods. No RN knowledge required on the native side. The native app's Tuist project definition references the XCFrameworks exactly as it does any other binary dependency today.

### What the consumer side looks like

```swift
// Project.swift (Tuist)
.xcframework(path: "path/to/tescornappbrownfield.xcframework"),
.xcframework(path: "path/to/hermesvm.xcframework"),
```

```swift
// Any SwiftUI view in the native app
import tescornappbrownfield

ReactNativeView(moduleName: "TescoRNApp", initialProps: ["userId": userId])
```

That is the complete integration contract for a native iOS developer. No CocoaPods, no RN toolchain, no ObjC.

---

## Fit with Tuist + SPM

This is the critical dimension for the platform team.

**Today:** Tuist supports binary XCFrameworks as first-class dependencies. The native app adds two lines to its project definition and gains access to the full RN surface. No impact on the 40 engineers who never touch RN. No workspace overhead. No CocoaPods lifecycle in the native build.

**If/when RN and Expo adopt SPM:** The XCFramework boundary is the right abstraction layer for this transition. The consumer API (`ReactNativeView`, `ReactNativeViewController`, `BrownfieldState`, `BridgeEvents`) stays identical. The platform team changes how the package is distributed — from a local binary XCFramework to an SPM binary target (`.binaryTarget(url:checksum:)`) or eventually a source package — and the native app team sees no difference.

The XCFramework model works correctly today and positions for the SPM migration without any consumer-side changes. It is, in this sense, a hedge against the toolchain transition.

---

## Native Module Authoring at Scale

For a platform team supporting 40 iOS engineers, the authoring model for new native capabilities matters significantly.

| Task | Approach 1 — ObjC++ TurboModules | Approach 3 — Expo Modules |
|---|---|---|
| Expose a new native function | 4 files, 2 languages | 1 Swift file |
| Run codegen | Manual | Automatic at build time |
| C++ spec maintenance | Required | None |
| Required knowledge | Swift + ObjC + C++ + codegen | Swift only |
| New team member ramp-up | High | Low |

As the feature set grows, each new native capability in approach 3 is one Swift file. The platform team publishes a new XCFramework version. The native app team updates the framework reference. No ObjC++ or C++ reaches any of the 40 iOS developers.

---

## Size

A parallel experiment producing a plain RN simulator build (debug configuration) surfaced size concerns. This PoC (RN 0.83.2, release configuration, expo-brownfield) produces measurably different results:

| Slice | tescornappbrownfield | hermesvm | Total |
|---|---|---|---|
| Device — arm64 release | 16 MB | 4.6 MB | **~21 MB** |
| Simulator — fat (arm64 + x86_64) | 30 MB | 9.2 MB | ~39 MB |
| XCFramework total (both slices) | 46 MB | 51 MB | ~97 MB |

The simulator fat binary is what looks alarming in isolation. The relevant number for a production decision is the **device arm64 release slice: ~21 MB** added to the host IPA. After App Store compression (LZFSE, typically ~30%), this is approximately **14–15 MB delivered to users**.

Critically, this is a **fixed floor, not a scaling cost**. Every additional RN-powered view adds only JS bundle bytes, not native binary bytes. The size question for Tesco is a one-time commercial decision at the start, not a recurring engineering concern.

### What drives the fixed base cost

| Component | Can be excluded | Notes |
|---|---|---|
| Hermes JS engine | No | Required to execute JS |
| React Fabric (C++ renderer) | No | New Architecture |
| Boost, Folly, glog, Yoga, DoubleConversion, fmt | No | RN C++ runtime dependencies |
| JSI + TurboModule core | No | Bridge mechanism |

These are RN itself. They cannot be removed or tree-shaken.

---

## Communication Architecture

The bridge between RN and the native app is layered to keep each concern isolated:

```
RN (TypeScript)
  └── Expo Module DSL (Swift)            ← one file per capability, no C++
        └── TurboModule / JSI layer      ← auto-generated, never hand-authored
              └── NotificationCenter     ← ObjC-compatible transport
                    └── BridgeEvents     ← Combine publisher, public API of XCFramework
                          └── CartState  ← ObservableObject in native app

Native app (SwiftUI)
  └── BrownfieldState                    ← key-value shared state (Combine)
  └── BrownfieldMessaging                ← bidirectional event bus (Combine)
```

The native app team subscribes to typed Combine publishers. NotificationCenter is an internal implementation detail of the framework, invisible at the consumer call site.

---

## Scalability

| Dimension | Scales well | Notes |
|---|---|---|
| Number of RN features / views | ✓ | Fixed native cost; JS grows linearly |
| Number of JS developers | ✓ | Standard React/Expo patterns apply |
| Number of native modules | ✓ | One Swift file each; no C++ |
| 40 native iOS engineers | ✓ | Zero RN toolchain knowledge required |
| Multiple product teams sharing one bundle | △ | Single runtime; governance model needed |
| Multiple app variants / white-label | △ | One XCFramework build per variant target |
| Independent release cadences per feature | ✗ | One bundle, one native framework, one release |

The single-instance constraint is the main architectural pressure point as the number of RN-owning teams grows. This is addressable (Metro bundle splitting, feature flags, module federation) but it is not free.

---

## Short Term vs Long Term

### Short term (0–6 months)

The PoC is demo-ready and proves the integration model works. The expo-brownfield pipeline is reproducible. The Tuist compatibility is confirmed. The Expo Module DSL eliminates ObjC++ from the authoring workflow.

A first production feature should be self-contained, non-critical, and owned by a single team — enough to prove the CI pipeline, the XCFramework distribution story, and the OTA update path under real conditions without high blast radius if something needs to change.

### Long term (6–24 months)

| Concern | Trajectory |
|---|---|
| RN / New Architecture maturity | Strong — Fabric and JSI are Meta's production bet at scale |
| Binary size | Stable — fixed floor, does not grow with feature count |
| CocoaPods on the build side | Needs a plan — CocoaPods trunk goes read-only late 2026 |
| SPM migration | The XCFramework boundary makes this a platform team concern, not a native app concern |
| Expo SDK upgrade cadence | ~3 months per major; manageable with CI automation; painful if neglected |
| Multi-team governance | Becomes the dominant challenge past the first two RN-owning teams |

---

## Open Points — Where to Focus Next

The architecture is validated. These are the questions that should drive the next experiments while change is still cheap.

### 1. JS bundle delivery strategy

Should the JS bundle ship bundled inside the app (build-time) or be fetched at runtime via EAS Update (OTA)? Bundled is simpler and offline-safe. OTA unlocks the main Expo value proposition — JS deployments decoupled from App Store review cycles. The decision affects CI, CDN infrastructure, rollback strategy, and crash attribution. This needs a concrete proof before committing.

### 2. XCFramework distribution and versioning

How does the RN team publish a new XCFramework to native developers? Options:

- **Committed to the repo** — current PoC approach, works at small scale
- **Binary store (S3 / Artifactory)** — referenced by Tuist via URL, same pattern as other internal SDKs
- **SPM binary target** — `.binaryTarget(url:checksum:)`, aligns with the Tuist/SPM model today

The right answer depends on Tesco's existing binary distribution infrastructure. This should be decided before the first production feature.

### 3. Single RN instance — multi-team governance

When a second product team wants to ship an RN view, both features share one JS bundle and one native framework. What is the API contract between teams? Who owns the framework build and its release cadence? How are conflicting native module requirements resolved? A short simulation with two independent feature teams would surface the real coordination cost early.

### 4. Performance baseline on a representative bundle

The current JS bundle is a trivial PoC (< 1 MB). A production Tesco screen will pull in react-navigation, state management, network layers, and product-domain logic. Measuring cold start and frame budget on a representative bundle size — before committing — is important data for the product conversation.

### 5. CocoaPods sunset on the build side

The Tesco native app (consumer) is clean of CocoaPods. The RN build environment that produces the XCFramework is not. The platform team should identify whether Tesco's internal infrastructure can host the RN pod spec graph, or whether the XCFramework build pipeline needs to front-run the SPM migration on the production side.

### 6. Expo SDK upgrade automation

Expo releases a new SDK approximately every three months. Before scaling to production, the XCFramework rebuild and validation pipeline — build, smoke test, publish — should be automated. Staying current should never be a manual obligation.

---

## Summary

| Criteria | Approach 1 | Approach 2 | Approach 3 (current) |
|---|---|---|---|
| Tuist + SPM compatible | ✗ | ✗ | ✓ |
| Zero CocoaPods in native app | ✗ | ✗ | ✓ |
| Swift-only native authoring | ✗ | ✓ | ✓ |
| OTA capable (Expo) | ✗ | ✗ | ✓ |
| SPM migration path | None | None | Minimal change |
| Native dev knowledge required | High | High | Minimal |
| Recommended | No | No | **Yes** |

The expo-brownfield XCFramework model is the right architecture for Tesco's constraints: a large native app, Tuist + SPM, a platform team responsible for the integration layer, and Expo as the RN framework of choice. The open points above are what should be experimented with next — they are integration and operational questions, not architectural ones.
