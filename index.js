/**
 * index.js — React Native entry point.
 *
 * The module name 'TescoRNApp' must match:
 *   - moduleName param in TescoRNHost.createRootViewWithModuleName:
 *   - moduleName param in ReactViewController
 */
import { AppRegistry } from 'react-native';
import App from './src/App';

AppRegistry.registerComponent('TescoRNApp', () => App);
