import UIKit

/// Hosts a Fabric-rendered React Native surface.
///
/// Does NOT import React — it receives a UIView from TescoRNHost and embeds it.
/// The only RN-specific knowledge here is the NotificationCenter callback contract.
final class ReactViewController: UIViewController {

    private let moduleName: String
    private let initialProps: [String: Any]
    private let rnHost: TescoRNHost

    init(moduleName: String, initialProps: [String: Any], rnHost: TescoRNHost) {
        self.moduleName = moduleName
        self.initialProps = initialProps
        self.rnHost = rnHost
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "React Native"
        view.backgroundColor = .systemBackground
        embedSurface()
        observeTurboModuleCallbacks()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private

    private func embedSurface() {
        // RCTRootViewFactory creates the Fabric surface view here.
        let rnView = rnHost.createRootView(withModuleName: moduleName, initialProperties: initialProps)
        rnView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rnView)
        NSLayoutConstraint.activate([
            rnView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rnView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func observeTurboModuleCallbacks() {
        // TescoNativeBridgeModule (Swift Expo module) posts from the JS/async thread.
        // The handler dispatches to main before touching UIKit.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleButtonTap(_:)),
            name: .tescoNativeBridgeButtonTapped,
            object: nil
        )
    }

    @objc private func handleButtonTap(_ notification: Notification) {
        let message = notification.userInfo?["message"] as? String ?? "Button tapped"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(
                title: "Native Callback",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - Notification name shared contract
// The string literal must match TescoNativeBridge.mm

extension Notification.Name {
    static let tescoNativeBridgeButtonTapped = Notification.Name("TescoNativeBridgeButtonTapped")
}
