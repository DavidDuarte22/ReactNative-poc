// Inline process.env.EXPO_OS as the literal platform string.
// expo-modules-core JS code expects babel-preset-expo to replace this at build
// time. Without it the module logs a warning and may use wrong platform paths.
// This tiny visitor replicates that substitution without requiring the full
// babel-preset-expo package.
function inlineExpoOS() {
  return {
    visitor: {
      MemberExpression(path) {
        if (
          path.get('object').matchesPattern('process.env') &&
          path.node.property.name === 'EXPO_OS'
        ) {
          path.replaceWith({type: 'StringLiteral', value: 'ios'});
        }
      },
    },
  };
}

module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [inlineExpoOS],
  // RN 0.84 uses Flow `match` expressions (TC39 pattern matching proposal)
  // which require enableExperimentalFlowMatchSyntax in the Hermes parser.
  parserOpts: {
    enableExperimentalFlowMatchSyntax: true,
  },
};
