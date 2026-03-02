pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  // PREFER_SETTINGS allows the included build's allprojects { repositories } to coexist
  // without failing. Settings-level repos take priority.
  repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://www.jitpack.io") }

    // Expo [📦] bundled modules ship pre-built AAR artifacts inside their npm packages.
    // The expo-autolinking-settings-plugin registers these local-maven-repos for the
    // included build (ReactNativeApp/android) but NOT for TescoAndroidApp. We must
    // declare them here so transitive deps from brownfield → :android:expo resolve.
    val rnModules = file("../ReactNativeApp/node_modules")
    val expoNested = file("${rnModules}/expo/node_modules")
    maven {
      url = uri("${expoNested}/expo-asset/local-maven-repo")
      content { includeGroup("expo.modules.asset") }
    }
    maven {
      url = uri("${expoNested}/expo-file-system/local-maven-repo")
      content { includeGroup("host.exp.exponent"); includeModule("host.exp.exponent", "expo.modules.filesystem") }
    }
    maven {
      url = uri("${expoNested}/expo-font/local-maven-repo")
      content { includeModule("host.exp.exponent", "expo.modules.font") }
    }
    maven {
      url = uri("${expoNested}/expo-keep-awake/local-maven-repo")
      content { includeModule("host.exp.exponent", "expo.modules.keepawake") }
    }
    maven {
      url = uri("${expoNested}/@expo/log-box/node_modules/@expo/dom-webview/local-maven-repo")
      content { includeGroup("expo.modules.webview") }
    }
  }
}

// Composite build: substitutes the brownfield Maven coordinate with the source project.
// In production, remove this block and depend on the Nexus/Artifactory artifact instead:
//   implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")
includeBuild("../ReactNativeApp/android") {
  dependencySubstitution {
    substitute(module("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield"))
      .using(project(":brownfield"))
  }
}

rootProject.name = "TescoAndroidApp"
include(":app")
