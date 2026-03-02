import SwiftUI
import tescornappbrownfield

struct HomeView: View {
    @ObservedObject private var cart = CartState.shared

    var body: some View {
        NavigationView {
            VStack {
                NavigationLink {
                    // ReactNativeView is the SwiftUI wrapper shipped in the XCFramework.
                    // Wrapping it here lets us attach our own toolbar badge to the RN screen.
                    RNScreenView()
                } label: {
                    Text("Open React Native Screen")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .navigationTitle("Tesco UIKit App")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CartBadgeView(count: cart.count)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

/// Thin wrapper so we can attach a toolbar to the RN surface — the badge
/// updates live while the user is on the RN screen and taps "Call Native".
private struct RNScreenView: View {
    @ObservedObject private var cart = CartState.shared

    var body: some View {
        ReactNativeView(
            moduleName: "TescoRNApp",
            initialProps: ["userId": "demo-user", "locale": "en-GB"]
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CartBadgeView(count: cart.count)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CartBadgeView: View {
    let count: Int

    private let tescoBlue = Color(red: 0, green: 83 / 255, blue: 159 / 255)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Inset the icon so the badge has room in the top-trailing corner
            Image(systemName: "cart.fill")
                .foregroundColor(tescoBlue)
                .font(.system(size: 22))
                .padding(.top, 8)
                .padding(.trailing, 8)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
    }
}
