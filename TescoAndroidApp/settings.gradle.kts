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
