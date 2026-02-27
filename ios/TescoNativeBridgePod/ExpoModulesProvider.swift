import ExpoModulesCore

/// Lists all Expo Modules used by the app.
/// AppContext.modulesProvider() discovers this class via NSClassFromString("ExpoModulesProvider").
/// The @objc name bypasses Swift module-name prefixing so the lookup works from any target.
@objc(ExpoModulesProvider)
public class ExpoModulesProvider: ModulesProvider {
  public override func getModuleClasses() -> [ExpoModuleTupleType] {
    return [
      (TescoNativeBridgeModule.self, nil),
    ]
  }
}
