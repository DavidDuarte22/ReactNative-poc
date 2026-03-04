import UIKit

/// Swift entry point for React Native. Owns TescoRNHost (the ObjC++ layer).
///
/// This is the only Swift file (besides ReactViewController) that references
/// any ObjC type from this integration. All C++ / RCT internals stay in TescoRNHost.mm.
final class ReactNativeHostManager: ReactNativeHostManaging {

    private let rnHost = TescoRNHost()

    // MARK: - ReactNativeHostManaging

    func warmUp() {
        // Triggers RCTHost.start() → Hermes initialises, JS bundle loads.
        // Safe to call multiple times; RCTHost guards against double-start.
        rnHost.start()
    }

    func makeReactViewController(initialProps: [String: Any]) -> UIViewController {
        // Pass a builder closure so the Fabric surface is created inside viewDidLoad,
        // not before the VC is on screen.
        ReactViewController(moduleName: "TescoRNApp", initialProps: initialProps, rnHost: rnHost)
    }
}
