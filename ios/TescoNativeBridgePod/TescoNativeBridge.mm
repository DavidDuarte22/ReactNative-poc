#import "TescoNativeBridge.h"

#if __has_include(<React/RCTBridgeModule.h>)

#import <ReactCommon/RCTTurboModule.h>

using namespace facebook::react;

// Notification name — must match Notification.Name.tescoNativeBridgeButtonTapped in Swift
static NSString *const kButtonTappedNotification = @"TescoNativeBridgeButtonTapped";

@implementation TescoNativeBridge

// Registers this class with the TurboModule registry under the name "TescoNativeBridge".
// This name must match TurboModuleRegistry.getEnforcing('TescoNativeBridge') in JS.
RCT_EXPORT_MODULE()

// Return the JSI wrapper. NativeTescoNativeBridgeSpecJSI is defined in
// codegen/TescoNativeBridgeSpec-generated.mm (pre-generated, committed to repo).
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
    return std::make_shared<NativeTescoNativeBridgeSpecJSI>(params);
}

// ---------------------------------------------------------------------------
// Native method called from JS: NativeTescoNativeBridge.onButtonTapped(message)
//
// Threading contract:
//   • requiresMainQueueSetup returns NO → module init on background thread (safe)
//   • The method body may be called on any JS thread
//   • We dispatch to main before posting the notification so any UI observer is safe
// ---------------------------------------------------------------------------
- (void)onButtonTapped:(NSString *)message
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject {
    NSDictionary *userInfo = @{ @"message": message };
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kButtonTappedNotification
                                                          object:nil
                                                        userInfo:userInfo];
    });
    resolve(nil);
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end

#endif // __has_include(<React/RCTBridgeModule.h>)
