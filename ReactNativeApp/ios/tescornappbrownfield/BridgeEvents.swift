import Combine
import Foundation

/// Typed Combine publishers for events emitted by the RN TurboModule layer.
/// The NotificationCenter transport is an internal implementation detail of this framework;
/// consumers subscribe via the Combine interface and never see NotificationCenter directly.
public enum BridgeEvents {
    public static let buttonTapped: AnyPublisher<Void, Never> =
        NotificationCenter.default
            .publisher(for: NSNotification.Name("TescoNativeBridgeButtonTapped"))
            .map { _ in () }
            .eraseToAnyPublisher()
}
