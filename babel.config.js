module.exports = {
  presets: ['module:@react-native/babel-preset'],
  // RN 0.84 uses Flow `match` expressions (TC39 pattern matching proposal)
  // which require enableExperimentalFlowMatchSyntax in the Hermes parser.
  parserOpts: {
    enableExperimentalFlowMatchSyntax: true,
  },
};
