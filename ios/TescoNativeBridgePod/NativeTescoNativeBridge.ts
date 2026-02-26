/**
 * NativeTescoNativeBridge.ts
 *
 * Codegen spec — the TypeScript source of truth for TescoNativeBridge.
 *
 * Running `pod install` triggers Codegen which reads this file and generates:
 *   - TescoNativeBridgeSpec/TescoNativeBridgeSpec.h   (ObjC protocol + C++ spec)
 *   - TescoNativeBridgeSpec/TescoNativeBridgeSpec-generated.mm  (JSI glue)
 *
 * The generated class name follows the convention: NativeTescoNativeBridgeSpecJSI
 * (referenced in TescoNativeBridge.mm's getTurboModule: method).
 */

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Called when the user taps the button in the React Native surface.
   * @param message  Descriptive string forwarded to the native UIAlertController.
   */
  onButtonTapped(message: string): Promise<void>;
}

// getEnforcing throws at runtime if the native module is missing (correct for required modules).
// Codegen only recognises .get() and .getEnforcing() — strictGet is not supported.
export default TurboModuleRegistry.getEnforcing<Spec>('TescoNativeBridge');
