import ExpoModulesCore

/// ObjC-callable bridge: wires an ExpoRuntime and RCTHost into a fresh AppContext.
///
/// Called from TescoRNHost on the JS thread (RCTHostRuntimeDelegate.host:didInitializeRuntime:).
/// JavaScriptActor.assumeIsolated installs global.expo synchronously before _loadJSBundle: fires,
/// so ExpoBridgeModule.maybeSetupAppContext finds global.expo already set and skips its
/// deprecated initialisation path.
@objc(ExpoModulesAdapter)
public class ExpoModulesAdapter: NSObject {
    @objc public static func setup(runtime: ExpoRuntime, hostWrapper: ExpoHostWrapper) {
        let appContext = AppContext()
        appContext.registerNativeModules()
        appContext.setHostWrapper(hostWrapper)
        JavaScriptActor.assumeIsolated {
            appContext._runtime = runtime
        }
    }
}
