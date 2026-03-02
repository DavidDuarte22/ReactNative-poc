import Combine
import Foundation
import tescornappbrownfield

final class CartState: ObservableObject {
    static let shared = CartState()

    @Published private(set) var count = 0

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = BridgeEvents.buttonTapped
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.count += 1 }
    }
}
