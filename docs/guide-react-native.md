# React Native Developer Guide

You own `ReactNativeApp`. Your job is to write JS screens, expose native capabilities via Expo Modules, and build the artifacts that native teams consume.

## Prerequisites

| Tool | Version |
|---|---|
| Node.js | ≥ 20.19.4 |
| npm | ≥ 9 |
| Xcode | ≥ 16.0 (for iOS builds) |
| CocoaPods | ≥ 1.15 (for iOS builds) |
| Android Studio | ≥ 2024.3 (for Android builds) |
| JDK | 21 (Android Studio embedded JBR works) |

## Setup

```bash
git clone <repo>
cd ReactNativePoC/ReactNativeApp
npm install          # also applies all node_modules patches via postinstall
```

## Running Metro

Metro must be running for development builds on both platforms.

```bash
cd ReactNativeApp
npm start
```

## iOS development

Run the RN app standalone (connects to Metro):

```bash
# Open the Xcode workspace after pod install
cd ReactNativeApp/ios
pod install
open ReactNativePoC.xcworkspace
# Build and run the ReactNativePoC scheme on a simulator
```

Build the XCFrameworks for distribution to the iOS team:

```bash
cd ReactNativeApp
npx expo-brownfield build:ios --release --scheme tescornappbrownfield
```

This produces two frameworks in `ios/tescornappbrownfield/`:
- `tescornappbrownfield.xcframework` — your app code + native modules
- `hermesvm.xcframework` — the Hermes JS engine

Copy both into `TescoUIKitApp/Frameworks/` and commit.

## Android development

The `ReactNativeApp/android` project builds the brownfield AAR library. `TescoAndroidApp` consumes it via Gradle composite build — no manual AAR copying needed during development.

To build the AAR directly:

```bash
cd ReactNativeApp/android
./gradlew :brownfield:assembleRelease
# Output: brownfield/build/outputs/aar/brownfield-release.aar
```

For production distribution, publish to Nexus/Artifactory instead of using the composite build. See [Android developer guide](guide-android.md).

## Adding a new RN screen

1. Create the component in `ReactNativeApp/src/`
2. Register it with `AppRegistry` in `index.js`:

```js
AppRegistry.registerComponent('MyScreen', () => MyScreen);
```

3. Native teams instantiate it by `moduleName`. No native changes required.

## Adding a new native capability (Expo Module)

Expo Modules are the standard bridge pattern in this repo — pure Swift on iOS, no codegen.

1. Create a module in `TescoNativeBridgePod/` (iOS) or `ReactNativeApp/android/` (Android)
2. Define the module using the Expo Module DSL:

```swift
// iOS — pure Swift, no ObjC++
public class MyModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MyModule")
    Function("doSomething") { (value: String) in
      // native implementation
    }
    Events("onSomethingHappened")
  }
}
```

```kotlin
// Android
class MyModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("MyModule")
    Function("doSomething") { value: String ->
      // native implementation
    }
    Events("onSomethingHappened")
  }
}
```

3. Add the TypeScript interface in `src/`:

```ts
import { NativeModules } from 'react-native';
export const MyModule = NativeModules.MyModule;
```

4. Rebuild the XCFramework (iOS) or sync the composite build (Android).

## JS layer structure

```
ReactNativeApp/src/
  components/     shared UI components
  screens/        AppRegistry entry points
  bridge/         TypeScript wrappers over native modules
```

## Testing

```bash
npm test           # Jest unit tests
npm run typescript # type check
```
