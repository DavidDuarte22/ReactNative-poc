import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let hostManager = ReactNativeHostManager()
        let rootView = HomeView(hostManager: hostManager)
        let homeVC = UIHostingController(rootView: rootView)

        let nav = UINavigationController(rootViewController: homeVC)
        nav.navigationBar.prefersLargeTitles = true

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}
