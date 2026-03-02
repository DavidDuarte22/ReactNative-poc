/**
 * index.js — React Native entry point.
 *
 * The module name 'TescoRNApp' must match:
 *   - moduleName param in TescoRNHost.createRootViewWithModuleName:
 *   - moduleName param in ReactViewController
 */
import { AppRegistry } from 'react-native';
import App from './src/App';

// 'TescoRNApp' — used by TescoAndroidApp (HomeScreen.kt → RootComponent.TescoRNApp)
//              — used by TescoUIKitApp (iOS consumer)
// 'main'      — used by the brownfield standalone test app (ReactNativeFragment → RootComponent.Main)
AppRegistry.registerComponent('TescoRNApp', () => App);
AppRegistry.registerComponent('main', () => App);
