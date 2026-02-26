#pragma once
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// ObjC interface to the React Native New Architecture host.
///
/// Implemented in TescoRNHost.mm (ObjC++) because RCTTurboModuleManagerDelegate
/// requires C++ method signatures. Swift sees only this clean ObjC API.
///
/// Internally owns RCTRootViewFactory with bridgelessEnabled:YES → RCTHost.
@interface TescoRNHost : NSObject

/// Starts RCTHost: loads the JS bundle via Hermes, initialises TurboModule manager.
/// Safe to call early (e.g. from the screen before the RN surface appears).
- (void)start;

/// Creates a Fabric-rendered surface view.
/// @param moduleName     Matches AppRegistry.registerComponent name in index.js
/// @param initialProperties  Props forwarded to the root JS component
- (UIView *)createRootViewWithModuleName:(NSString *)moduleName
                       initialProperties:(nullable NSDictionary *)initialProperties;

@end

NS_ASSUME_NONNULL_END
