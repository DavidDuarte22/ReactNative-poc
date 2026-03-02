// expo/metro-config (re-exports @expo/metro-config) sets up the URL rewriter that
// intercepts /.expo/.virtual-metro-entry.bundle requests and rewrites them to the
// real entry point (index.bundle). Without this, Metro 404s on the virtual URL.
const {getDefaultConfig} = require('expo/metro-config');
const {mergeConfig} = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 */
const config = {};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
