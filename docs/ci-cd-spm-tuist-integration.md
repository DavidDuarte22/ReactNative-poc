# CI/CD Integration: React Native + Tesco SPM/Tuist Pipeline

## The Core Tension

| Tesco's world | React Native's world |
|---|---|
| SPM + Tuist | CocoaPods (required) |
| Static linking (default) | Needs `use_frameworks! :dynamic` for SPM via `spm_dependency` |
| No Podfile | Podfile is mandatory |
| Single pipeline | Needs RN build step |

You can't just drop RN into Tesco's existing Tuist project without contaminating it with CocoaPods. The "isolated dependency" requirement is the right instinct — it's the only clean path forward.

---

## Why SPM via `spm_dependency` Does NOT Work

The `spm_dependency` helper (available since RN 0.75, local packages in RN 0.84) allows adding SPM deps inside a podspec. However:

- It forces `use_frameworks! :linkage => :dynamic` on the **entire** project.
- The New Architecture **requires static frameworks** — dynamic linking breaks C++ TurboModules and causes linker failures.
- Result: **incompatible with New Architecture**.

The Expo config plugin approach (auto-modifying Xcode project via `withXcodeProject`) is designed exclusively for the **Expo managed workflow** where the `ios/` folder is regenerated on every build. It is not applicable to a bare React Native project with a committed Xcode project.

---

## Three Viable Strategies

### Option A — Pre-compiled XCFramework via SPM Binary Target *(best long-term isolation)*

The RN module lives in **its own repo** with its own CI/CD pipeline. That pipeline builds everything — RN, Hermes, Fabric, TurboModules, custom native code — into a single `TescoRNModule.xcframework`, packages the JS bundle as an embedded resource, and publishes to GitHub as a tagged release with a `Package.swift`.

Tesco's Tuist project then simply:

```swift
.binaryTarget(
    name: "TescoRNModule",
    url: "https://github.com/tesco/tesco-rn-module/releases/download/1.0.0/TescoRNModule.xcframework.zip",
    checksum: "abc123..."
)
```

Tuist handles binary XCFramework dependencies natively — no CocoaPods anywhere in the main project.

**Reference implementation:** [`whop-ios-react-native-kit`](https://github.com/whopio/whop-ios-react-native-kit) uses exactly this pattern. Their `setup.sh` drives the CocoaPods build + `xcodebuild -create-xcframework` step; `publish.sh` pushes the zip + checksum to a GitHub release.

**Pros:**
- Complete isolation — Tesco's pipeline never touches CocoaPods.
- RN is versioned like any other dependency.
- Build times for the main app are fast (binary, no compilation).

**Cons:**
- Building a valid all-in-one XCFramework from RN is complex. RN ships as ~50+ frameworks internally. You'd need to decide: merge them all (fat binary via `libtool`), or ship multiple XCFrameworks bundled in a zip.
- With `RCT_USE_PREBUILT_RNCORE=1` (available since RN 0.81), the C++ deps (Folly, Hermes, etc.) are already pre-built — this significantly reduces what you need to compile.
- JS bundle must be embedded as a resource bundle or served remotely (hot reload becomes harder in dev).
- Debugging and symbolication require dSYM files published alongside the framework.
- Symbol visibility — RN's internal ObjC classes must be explicitly exported or hidden to avoid duplicate symbol issues.

---

### Option B — Separate Xcode Subproject (CocoaPods side-by-side, not merged) *(pragmatic MVP)*

The RN workspace (`ReactNativePoC.xcworkspace`) stays completely separate. Tesco's Tuist project doesn't know about CocoaPods at all. Instead:

1. **RN CI step** (separate pipeline job): builds `ReactNativePoC.xcarchive` or `.xcframework` from the RN workspace.
2. **Tesco CI step**: consumes the output as a local `XCFramework` dependency or embedded framework.

In Tuist's `Project.swift`:

```swift
dependencies: [
    .xcframework(path: .relativeToManifest("../rn-module/build/TescoRNModule.xcframework"))
]
```

On CI, it's a downloaded artifact from the RN pipeline. The main app pipeline has a dependency gate: "RN module must build first."

**Pros:**
- Achieves isolation without the complexity of full XCFramework packaging.
- CocoaPods stays entirely in the RN repo.
- Can be implemented now with the current RN 0.84 setup.
- Metro hot reload still works — it runs independently of this build step.

**Cons:**
- Two-stage pipeline with an artifact dependency.
- Local dev requires building the RN module separately first (unless a pre-built version is cached or checked in).

---

### Option C — Tuist + CocoaPods Hybrid in Same Repo *(lowest isolation, quickest start)*

Run Tuist and CocoaPods sequentially on the same project:

```sh
tuist install → tuist generate --no-open → pod install
```

Tuist generates the project, then CocoaPods wraps it in a workspace with the Pods. Manual xcconfig path tweaks are required for `FRAMEWORK_SEARCH_PATHS`, `HEADER_SEARCH_PATHS`, and `OTHER_LDFLAGS`.

**Pros:**
- Single repo, single (sequential) build step once configured.

**Cons:**
- **Breaks the "isolated dependency" requirement** — CocoaPods bleeds into the main project.
- Tuist v3+ has explicitly dropped CocoaPods support.
- Growing maintenance burden for xcconfig path overrides as dependencies change.
- Not a viable long-term strategy.

---

## Recommendation

### Short term (MVP) → Option B

Ship a separate RN workspace, build it as a CI artifact, reference it via local `XCFramework` path in Tuist. Gets Tesco unblocked without touching their pipeline at all.

### Medium term → Option A

Invest in the `setup.sh` / `publish.sh` pipeline using `whop-ios-react-native-kit` as a reference. With `RCT_USE_PREBUILT_RNCORE=1` available since RN 0.81, you only package your own code + Hermes — not all of RN's C++ deps from scratch. Upgrading from 0.84 towards the precompiled mode is well-aligned with the project's direction anyway.

### Key CI/CD design principle (applies to all options)

> The RN module needs its own pipeline that produces a versioned artifact.
> The Tesco main app pipeline **only consumes** that artifact.
> **Never let `pod install` run in the main app's CI job.**

---

## Context: Full SPM Migration

CocoaPods is scheduled to stop accepting new podspecs on **December 2, 2026**. The RN team's stated migration plan:

1. Use Swift packages **alongside** CocoaPods (hybrid phase, already started with precompiled XCFrameworks in RN 0.81).
2. Eventually go SPM-only when CocoaPods is deprecated.

Full SPM support for React Native itself (replacing CocoaPods entirely) is expected in **RN 0.85+**. Until then, the strategies above represent the viable isolation approaches.

---

## Sources

- [Supporting React Native on moving on from CocoaPods — Tuist Community](https://community.tuist.dev/t/supporting-react-native-on-moving-on-from-cocoapods/164)
- [Precompiled React Native for iOS — Expo blog](https://expo.dev/blog/precompiled-react-native-for-ios)
- [whop-ios-react-native-kit — GitHub](https://github.com/whopio/whop-ios-react-native-kit)
- [Streamlining Dependencies: Tuist + CocoaPods + SPM — Halodoc](https://blogs.halodoc.io/streamlining-dependencies-how-tuist-enables-cocoapods-and-swift-package-manager-integration/)
- [Tuist dependencies documentation](https://docs.tuist.dev/guides/develop/projects/dependencies)
- [Bringing `use_frameworks!` to New Architecture — reactwg discussion #115](https://github.com/reactwg/react-native-new-architecture/discussions/115)
- [Integrating Swift Package Manager With React Native Libraries — Callstack](https://www.callstack.com/blog/integrating-swift-package-manager-with-react-native-libraries)
- [SPM community proposal — react-native-community/discussions #587](https://github.com/react-native-community/discussions-and-proposals/issues/587)
