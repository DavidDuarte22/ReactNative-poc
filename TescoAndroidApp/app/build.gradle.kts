plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
  id("org.jetbrains.kotlin.plugin.compose")
}

android {
  namespace = "com.tesco.tescoandroidapp"
  compileSdk = 36

  defaultConfig {
    applicationId = "com.tesco.tescoandroidapp"
    minSdk = 24
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"
  }

  buildTypes {
    release {
      isMinifyEnabled = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
    }
  }

  buildFeatures {
    compose = true
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = "17"
  }
}

dependencies {
  // Brownfield library — provides ReactNativeHostManager, ReactNativeViewFactory, BridgeEvents.
  // Resolved via composite build (see settings.gradle.kts).
  // In production, replace with a versioned Nexus artifact.
  implementation("com.parser.rnpoc.ReactNativePoC.brownfield:brownfield:1.0.0")

  // AppCompat — required because MainActivity extends BrownfieldActivity (extends AppCompatActivity)
  implementation("androidx.appcompat:appcompat:1.7.0")

  // react-android compileOnly: BrownfieldActivity implements DefaultHardwareBackBtnHandler from
  // react-android, which is an `implementation` dep of :brownfield (not api). The Kotlin compiler
  // needs the type on the classpath because MainActivity extends BrownfieldActivity. Runtime
  // classes are bundled inside the APK via brownfield's transitive deps — no duplication.
  compileOnly("com.facebook.react:react-android:0.83.2")

  // Fragment support — required by ReactNativeViewFactory (wraps ReactDelegate in a Fragment)
  implementation("androidx.fragment:fragment-ktx:1.8.4")

  // Compose BOM (pins all Compose library versions)
  val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
  implementation(composeBom)
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.ui:ui-tooling-preview")
  implementation("androidx.compose.material3:material3")

  // Activity Compose integration
  implementation("androidx.activity:activity-compose:1.9.3")

  // Lifecycle — ViewModel + coroutines
  implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")

  debugImplementation("androidx.compose.ui:ui-tooling")
}
