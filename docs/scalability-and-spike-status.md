# Scalability & Spike Plan Status

**Reference document** — maps the spike results against the original plan and
answers how the architecture scales across code, teams, and CI.

**Last updated:** 2026-03-03
**Spike plan:** `EXPO-Brownfield-Spike-Plan.md`

---

## Spike Plan Status at a Glance

| # | Validation | Status | Blocking what |
|---|---|---|---|
| **V1** | Expo Module builds in Tuist / SPM (iOS) | ✅ Effectively done | Consumer links XCFrameworks — Expo never in Tuist graph. `Project.swift` test still to write (1h). |
| **V2** | Zero cost for unflagged users | ❌ Not done | **Phase 1 blocker.** RN boots eagerly on both platforms. Must be behind a flag. |
| **V3** | Firebase Remote Config timing safety | ❌ Not done | No Firebase in PoC. Depends on V2. |
| **V4** | Bidirectional context sharing | ⚠️ Partial | Native→RN ✅. RN→Native ✅. Native→RN *after* mount ❌. |
| **V5** | Third-party native lib without CocoaPods | ❌ Not done | Most likely Phase 1 failure point. |
| **V6** | OTA via Expo Updates | ❌ Not done | **Phase 3 blocker.** Bundle baked into binary at build time. |
| **V7** | Android Gradle integration | ✅ Done | End-to-end on emulator. Events, lifecycle, dev mode all working. |
| **V8** | Binary size measurement | ⚠️ Partial | iOS measured (~21 MB, ~14 MB compressed). Android not measured. No baseline. |
| **V9** | CI/CD pipeline | ❌ Not done | Designed but not implemented. |

**Phase 1 gate:** V2 is the only hard blocker remaining to start the production conversation.

---

## How It Scales

### Code

**What scales well:**
- **The binary boundary is the seam.** The RN team ships a framework/AAR; consumer teams link it.
  Adding a new RN screen = register a new `AppRegistry` component name. No native rebuild needed.
- **Expo Module DSL scales for new native modules.** One Swift or Kotlin file per module.
  No ObjC++ boilerplate. Any iOS/Android engineer can write one in a day.
- **JS bundle changes are isolated.** Updating `App.tsx` or adding a new screen doesn't
  require touching the XCFramework or AAR — until a new native module is needed.

**What doesn't scale:**
- **One JS bundle, one Hermes runtime per app.**
  All RN-powered features share the same JS process and the same `package.json`.
  With 2+ product teams contributing screens, you need governance:
  - Who approves new JS dependencies?
  - Who owns the RN version upgrade?
  - What's the release cadence for the bundle vs the XCFramework?

  This is the dominant scaling challenge past two teams. The answer is a Platform team
  that owns the bundle and treats it like a shared library.

- **Every new native module triggers a full XCFramework rebuild.**
  A new Expo Module (Swift/Kotlin) means a new build and a new XCFramework version to
  distribute. This is fine for infrequent platform additions, but if teams are adding
  native modules weekly, the pipeline needs to be fast and automated (V9).

- **RN version is pinned to Expo SDK.**
  RN 0.83.2 is locked to Expo SDK 55. Upgrading RN means upgrading Expo SDK and
  re-validating all 7 iOS build workarounds. Plan one upgrade cycle per quarter at most.

---

### Teams

**Consumer teams (iOS / Android) — minimal impact:**

| They need | They don't need |
|---|---|
| Xcode or Android Studio | Node, npm, CocoaPods |
| Add 2 files (AppDelegate + HomeView style) | Any RN or Expo knowledge |
| Link XCFramework / add AAR dep | Understanding of JS bundle |
| React to typed events (Combine / SharedFlow) | Direct RN imports |

The binary boundary is a real wall. A new iOS engineer can embed and use
the RN surface without ever opening the RN repo.

**RN team — owns the full pipeline:**
- `ReactNativeApp/` — JS source, Expo modules, native bridge code
- XCFramework build (CocoaPods still needed on their machines)
- Android brownfield library build
- JS bundle and OTA publishing (once V6 is done)
- Versioning and changelog for the binary artifact

**Multi-team RN contribution (future):**
When a second product team wants to add an RN screen, they need to work
inside `ReactNativeApp/src/`. The RN team acts as a platform layer:
- Exposes a versioned API for registering component names
- Reviews native module additions (they affect the binary size and build)
- Controls when `package.json` dependencies are added or upgraded

---

### CI

**Three independent pipelines are needed:**

| Pipeline | Trigger | Output | Estimated time |
|---|---|---|---|
| **XCFramework build** | Change in `ios/` or `NativeTescoNativeBridge` | New XCFrameworks in `artifacts/` → publish to Artifactory | ~20–40 min |
| **Android AAR build** | Change in `android/brownfield/` | New AAR → publish to Nexus | ~10–15 min |
| **JS / OTA** | Change in `src/` or `package.json` | Updated bundle → `eas update` to EAS server | ~3–5 min |

**Key insight:** most day-to-day changes are JS only (`src/`).
Those go through the fast OTA pipeline without touching the native builds.
Native builds only trigger when a new Expo Module or native dependency is added.
This is the main operational advantage of the Expo architecture over Bare RN.

**Status:** Pipelines are designed (see `platform-guide.md`) but none are implemented.
V9 is open.

---

## What to Tackle — Prioritised

### Cannot ship to production without these

1. **V2 — Lazy init + feature flag (both platforms)**
   Move `ReactNativeHostManager.initialize()` behind `rn_spike_enabled` flag.
   Profile with Instruments / Android Studio Profiler.
   Pass criteria: < 5ms launch delta, < 1MB memory delta, zero RN symbols in trace.
   *This is the non-negotiable gate with 10M+ users.*

2. **V3 — Firebase Remote Config timing**
   Depends on V2. Validate the 5 edge cases from the spike plan
   (first install, stale cache, network unavailable, flag flip both directions).

3. **V5 — Third-party native library (iOS)**
   Add one library with native iOS code. Confirm it doesn't leak CocoaPods into the consumer.
   *Highest probability failure point in Phase 1.*

### Important before scaling to a second team

4. **V6 — OTA via Expo Updates (both platforms)**
   Bundle is currently baked into the binary. This is Expo's main advantage over Bare RN.
   If OTA doesn't work in brownfield embedding, the architecture choice needs re-evaluation.

5. **V8 — Android binary size**
   Measure APK/AAB before and after adding the brownfield dep. Document the delta.

6. **V9 — CI pipelines**
   Without automation the XCFramework build is a manual step.
   Unacceptable for a shared platform used by multiple teams.

### Before Phase 2 A/B test

7. **Representative bundle performance**
   Current bundle is trivial. Build a bundle with navigation, API calls, and state management.
   Measure cold start on a mid-range Android device and iPhone 12 or equivalent.
   Do this before any A/B test commitment.

---

## What Is Not Compatible

These are hard incompatibilities — not workarounds, not risks. Things that simply don't work:

| Incompatibility | Detail |
|---|---|
| **Gradle 9.0** | IBM_SEMERU field-not-found error in the RN Gradle plugin. Hard-pinned to Gradle 8.x until RN fixes the plugin. |
| **React Native 0.84+ with Expo SDK 55** | RN 0.84 added `bundleConfiguration` param that breaks Expo SDK 55 Swift templates. Cannot upgrade RN without upgrading Expo SDK. Expo SDK 56 not released at time of writing. |
| **CocoaPods-free build side (RN team)** | The consumer is CocoaPods-free. The XCFramework *build* still requires `pod install`. CocoaPods trunk goes read-only late 2026 — needs a plan. |
| **Multiple independent JS bundles** | One RN runtime per app process. You cannot have two product teams running isolated bundles in the same app. Shared bundle is the only model. |
| **SPM as source deps for Expo (build side)** | Expo modules cannot be added as SPM source dependencies yet (RN 0.85+ may change this). CocoaPods required on the RN team's build machines. |
| **Android Gradle 9.0 `react.internal.disableJavaVersionAlignment`** | The flag needed for Gradle 9 breaks Kotlin/Java JVM target alignment on Gradle 8.x, causing expo-modules-core compilation failure. The two are mutually exclusive. |

---

## Open Questions Before Phase 1 Go/No-Go

From the original spike plan — not yet answered:

- [ ] Which third-party libraries will the real feature need? (drives V5 selection)
- [ ] What are the baseline launch time and memory numbers before RN is added?
- [ ] What is the acceptable binary size increase threshold? (stakeholder input needed)
- [ ] What is the acceptable CI build time increase?
- [ ] EAS account setup for OTA testing
- [ ] Is brief test screen visibility during stale cache acceptable? (V3 edge case)

---

## Decision Points

| Decision | Condition | Options |
|---|---|---|
| **Phase 1 go** | V1 ✅, V7 ✅, V2 ✅, V4 ✅ | Proceed to Phase 2 |
| **Phase 1 conditional go** | Above pass but V5 fails | Accept partial CocoaPods, use Expo alternatives, or fork the library |
| **Phase 1 no-go** | V2 fails (can't achieve zero cost) | Bare RN + CocoaPods, or re-evaluate RN entirely |
| **Phase 3 go** | V6 ✅ (OTA works in brownfield) | Commit to Expo Modules architecture |
| **Phase 3 no-go** | V6 fails | Expo loses its main advantage over Bare RN. Reassess. |
