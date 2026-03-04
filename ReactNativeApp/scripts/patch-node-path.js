/**
 * Patches hardcoded `commandLine("node", ...)` calls in nested node_modules that
 * patch-package cannot target. These scripts are applied directly by Gradle at
 * configuration time, so they must use System.getProperty("node.executable", "node")
 * — the same property set by settings.gradle — to work when launched from
 * Android Studio (which inherits a minimal macOS launchd PATH without homebrew).
 */

const fs = require('fs');
const path = require('path');

const PATCHES = [
  {
    file: 'node_modules/expo/node_modules/expo-constants/scripts/get-app-config-android.gradle',
    find: 'commandLine("node", "-e"',
    replace: 'commandLine(System.getProperty("node.executable", "node"), "-e"',
  },
  {
    file: 'node_modules/expo/node_modules/expo-constants/scripts/get-app-config-android.gradle',
    find: 'config.nodeExecutableAndArgs ?: ["node"]',
    replace: 'config.nodeExecutableAndArgs ?: [System.getProperty("node.executable", "node")]',
  },
];

let allOk = true;

for (const { file, find, replace } of PATCHES) {
  const filePath = path.resolve(__dirname, '..', file);

  if (!fs.existsSync(filePath)) {
    console.warn(`⚠  patch-node-path: file not found, skipping: ${file}`);
    continue;
  }

  const original = fs.readFileSync(filePath, 'utf8');

  if (original.includes(replace)) {
    console.log(`✓  patch-node-path: already patched: ${file}`);
    continue;
  }

  if (!original.includes(find)) {
    console.warn(`⚠  patch-node-path: pattern not found, skipping: ${file}`);
    allOk = false;
    continue;
  }

  fs.writeFileSync(filePath, original.replace(find, replace));
  console.log(`✓  patch-node-path: patched: ${file}`);
}

if (!allOk) {
  process.exit(1);
}
