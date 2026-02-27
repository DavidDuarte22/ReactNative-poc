import ExpoModulesCore

public class TescoNativeBridgeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("TescoNativeBridge")

    AsyncFunction("onButtonTapped") { (message: String) in
      NotificationCenter.default.post(
        name: .init("TescoNativeBridgeButtonTapped"),
        object: message
      )
    }
  }
}
