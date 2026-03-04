import UIKit
import SwiftUI
import tescornappbrownfield

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = CartState.shared              // boot NotificationCenter observer before any RN surface fires
        ReactNativeHostManager.shared.initialize()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: HomeView())
        window?.makeKeyAndVisible()
        return true
    }
}
