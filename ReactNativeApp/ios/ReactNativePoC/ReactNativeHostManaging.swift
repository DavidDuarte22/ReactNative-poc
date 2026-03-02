import UIKit

/// The only protocol HomeView (and any other native screen) depends on.
/// Zero React Native types are visible through this interface.
protocol ReactNativeHostManaging: AnyObject {
    /// Pre-warm the JS engine (RCTHost bridgeless start).
    /// Call as early as possible — e.g. onAppear of the preceding screen.
    func warmUp()

    /// Creates a UIViewController hosting a Fabric-rendered React Native surface.
    func makeReactViewController(initialProps: [String: Any]) -> UIViewController
}
