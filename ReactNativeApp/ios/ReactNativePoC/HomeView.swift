import SwiftUI
import UIKit

/// Native home screen — zero React Native imports.
/// Navigation is driven by injecting into the UINavigationController via the coordinator.
struct HomeView: View {

    let hostManager: ReactNativeHostManaging

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0, green: 0.329, blue: 0.624)) // Tesco blue

            Text("Tesco PoC")
                .font(.largeTitle.bold())

            Text("Native → React Native push demo")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Open React Native Screen") {
                openRNScreen()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0, green: 0.329, blue: 0.624))
            .padding(.top, 16)
        }
        .padding()
        .onAppear {
            hostManager.warmUp()
        }
    }

    private func openRNScreen() {
        let reactVC = hostManager.makeReactViewController(
            initialProps: [
                "userId": "tesco-user-42",
                "locale": Locale.current.identifier,
            ]
        )
        // Push onto the UINavigationController that owns our UIHostingController.
        UIApplication.shared.topNavigationController?.pushViewController(reactVC, animated: true)
    }
}

// MARK: - UIApplication helper

private extension UIApplication {
    var topNavigationController: UINavigationController? {
        (connectedScenes.first as? UIWindowScene)?
            .windows.first(where: \.isKeyWindow)?
            .rootViewController as? UINavigationController
    }
}
