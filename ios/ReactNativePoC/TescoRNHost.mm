#import "TescoRNHost.h"

#if __has_include(<RCTRootViewFactory.h>)

#import <RCTRootViewFactory.h>
#import <React/RCTBundleURLProvider.h>
#import <ReactCommon/RCTTurboModuleManager.h>
#import <React/CoreModulesPlugins.h>
// RN 0.84: Hermes runtime factory required by RCTJSRuntimeConfiguratorProtocol
#import <React/RCTHermesInstanceFactory.h>
#import <React/RCTNetworking.h>
#import <React/RCTHTTPRequestHandler.h>
#import <React/RCTDataRequestHandler.h>
#import <React/RCTFileRequestHandler.h>
#import <TescoNativeBridge/TescoNativeBridge.h>
#include <react/nativemodule/defaults/DefaultTurboModules.h>
#include <react/featureflags/ReactNativeFeatureFlags.h>
#include <react/featureflags/ReactNativeFeatureFlagsOverridesOSSStable.h>

using namespace facebook::react;

// ---------------------------------------------------------------------------
// TescoRNHost — brownfield host for React Native 0.84 New Architecture.
//
// In RN 0.84, RCTRootViewFactory requires the caller to supply a JS runtime
// factory via RCTJSRuntimeConfiguratorProtocol. We implement it here to
// return the Hermes runtime (same engine used by default in all RN 0.84 apps).
// ---------------------------------------------------------------------------

@interface TescoRNHost () <RCTTurboModuleManagerDelegate, RCTJSRuntimeConfiguratorProtocol>
@property (nonatomic, strong) RCTRootViewFactory *factory;
@property (nonatomic, assign) BOOL started;
@end

@implementation TescoRNHost

- (instancetype)init {
    if (self = [super init]) {
        // Initialize React Native feature flags for bridgeless New Architecture.
        // We use dangerouslyForceOverride (not override) because some flags may
        // be accessed early (e.g. InspectorFlags singleton) before TescoRNHost
        // is instantiated. dangerouslyForceOverride creates a fresh accessor and
        // swaps it in, bypassing the "accessed before override" guard.
        static dispatch_once_t featureFlagToken;
        dispatch_once(&featureFlagToken, ^{
            ReactNativeFeatureFlags::dangerouslyForceOverride(
                std::make_unique<ReactNativeFeatureFlagsOverridesOSSStable>());
        });

        RCTRootViewFactoryConfiguration *config =
            [[RCTRootViewFactoryConfiguration alloc]
                initWithBundleURLBlock:^NSURL * _Nonnull {
                    return [RCTBundleURLProvider.sharedSettings
                            jsBundleURLForBundleRoot:@"index"];
                }
                newArchEnabled:YES];

        // Required in RN 0.84: supply the Hermes JS runtime factory.
        config.jsRuntimeConfiguratorDelegate = self;

        _factory = [[RCTRootViewFactory alloc]
                        initWithConfiguration:config
                   andTurboModuleManagerDelegate:self];
    }
    return self;
}

// MARK: - RCTJSRuntimeConfiguratorProtocol (RN 0.84)

- (JSRuntimeFactoryRef)createJSRuntimeFactory {
    return jsrt_create_hermes_factory();
}

// MARK: - Public API

- (void)start {
    if (_started) return;
    _started = YES;
    [_factory createReactHost:nil];
}

- (UIView *)createRootViewWithModuleName:(NSString *)moduleName
                       initialProperties:(NSDictionary *)initialProperties {
    return [_factory viewWithModuleName:moduleName
                      initialProperties:initialProperties
                          launchOptions:nil];
}

// MARK: - RCTTurboModuleManagerDelegate

/// Return the Class for a module by name. RCTCoreModulesClassProvider handles all built-in RN modules.
- (Class)getModuleClassFromName:(const char *)name {
    if (strcmp(name, "TescoNativeBridge") == 0) {
        return [TescoNativeBridge class];
    }
    return RCTCoreModulesClassProvider(name);
}

/// RN 0.84 required method: given a class, return a custom instance (or nil for default init).
/// RCTNetworking requires a custom init with HTTP/data/file request handlers so that
/// dev-tools symbolication and JS fetch() work in New Architecture (bridgeless) mode.
- (id<RCTTurboModule>)getModuleInstanceFromClass:(Class)moduleClass {
    if (moduleClass == RCTNetworking.class) {
        return (id<RCTTurboModule>)[[RCTNetworking alloc]
            initWithHandlersProvider:^NSArray<id<RCTURLRequestHandler>> *(RCTModuleRegistry *moduleRegistry) {
                return @[
                    [RCTHTTPRequestHandler new],
                    [RCTDataRequestHandler new],
                    [RCTFileRequestHandler new],
                ];
            }];
    }
    return nil;
}

/// Provide C++ TurboModules. Always delegate to DefaultTurboModules so that
/// core RN C++ modules (NativeMicrotasksCxx, etc.) are auto-registered.
- (std::shared_ptr<TurboModule>)getTurboModule:(const std::string &)name
                                     jsInvoker:(std::shared_ptr<CallInvoker>)jsInvoker {
    return DefaultTurboModules::getTurboModule(name, jsInvoker);
}

@end

#else
// Pre-pod-install stub.
@implementation TescoRNHost
- (void)start {}
- (UIView *)createRootViewWithModuleName:(NSString *)moduleName
                       initialProperties:(NSDictionary *)initialProperties {
    UILabel *label = [[UILabel alloc] init];
    label.text = @"Run pod install to enable React Native.";
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}
@end
#endif
