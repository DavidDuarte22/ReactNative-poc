#import "TescoRNHost.h"

#if __has_include(<RCTRootViewFactory.h>)

#import <RCTRootViewFactory.h>
#import <React/RCTBundleURLProvider.h>
#import <ReactCommon/RCTTurboModuleManager.h>
#import <React/CoreModulesPlugins.h>
#import <React/RCTHermesInstanceFactory.h>
#import <React/RCTNetworking.h>
#import <React/RCTHTTPRequestHandler.h>
#import <React/RCTDataRequestHandler.h>
#import <React/RCTFileRequestHandler.h>
#import <ExpoModulesCore/EXRuntime.h>
#import <ExpoModulesCore/EXHostWrapper.h>
#import "ReactNativePoC-Swift.h"
#include <react/nativemodule/defaults/DefaultTurboModules.h>
#include <react/featureflags/ReactNativeFeatureFlags.h>
#include <react/featureflags/ReactNativeFeatureFlagsOverridesOSSStable.h>
#include <ReactCommon/RCTHost.h>

using namespace facebook::react;

@interface TescoRNHost () <RCTTurboModuleManagerDelegate,
                           RCTJSRuntimeConfiguratorProtocol,
                           RCTHostRuntimeDelegate>
@property (nonatomic, strong) RCTRootViewFactory *factory;
@property (nonatomic, assign) BOOL started;
@end

@implementation TescoRNHost

- (instancetype)init {
    if (self = [super init]) {
        // dangerouslyForceOverride is required (not override) because some flags may
        // be accessed before TescoRNHost is instantiated; override() would silently fail.
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

        config.jsRuntimeConfiguratorDelegate = self;

        _factory = [[RCTRootViewFactory alloc]
                        initWithConfiguration:config
                   andTurboModuleManagerDelegate:self];
    }
    return self;
}

// MARK: - RCTJSRuntimeConfiguratorProtocol

- (JSRuntimeFactoryRef)createJSRuntimeFactory {
    return jsrt_create_hermes_factory();
}

// MARK: - Public API

- (void)start {
    if (_started) return;
    _started = YES;
    // createReactHost: returns the new host but does not store it in factory.reactHost.
    // Assign it manually so that the later viewWithModuleName: call reuses the same instance.
    RCTHost *host = [_factory createReactHost:nil];
    _factory.reactHost = host;
    host.runtimeDelegate = self;
}

- (UIView *)createRootViewWithModuleName:(NSString *)moduleName
                       initialProperties:(NSDictionary *)initialProperties {
    return [_factory viewWithModuleName:moduleName
                      initialProperties:initialProperties
                          launchOptions:nil];
}

// MARK: - RCTHostRuntimeDelegate

- (void)host:(RCTHost *)host didInitializeRuntime:(facebook::jsi::Runtime &)runtime {
    EXRuntime *expoRuntime = [[EXRuntime alloc] initWithRuntime:runtime];
    EXHostWrapper *hostWrapper = [[EXHostWrapper alloc] initWithHost:host];
    [ExpoModulesAdapter setupWithRuntime:expoRuntime hostWrapper:hostWrapper];
}

// MARK: - RCTTurboModuleManagerDelegate

- (Class)getModuleClassFromName:(const char *)name {
    // ExpoBridgeModule (registered as "ExpoModulesCore") is initialised via
    // host:didInitializeRuntime: instead of the TurboModule path.
    if (strcmp(name, "ExpoModulesCore") == 0) {
        return nil;
    }
    return RCTCoreModulesClassProvider(name);
}

- (id<RCTTurboModule>)getModuleInstanceFromClass:(Class)moduleClass {
    // RCTNetworking requires a custom init so that HTTP/data/file handlers are
    // registered in bridgeless mode (needed for fetch() and dev-tools symbolication).
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
