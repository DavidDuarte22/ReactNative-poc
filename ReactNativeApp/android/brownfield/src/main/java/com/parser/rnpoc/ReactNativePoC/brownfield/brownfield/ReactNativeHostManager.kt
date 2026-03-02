package com.parser.rnpoc.ReactNativePoC.brownfield.brownfield

import android.app.Activity
import android.app.Application
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import com.facebook.react.PackageList
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.common.ReleaseLevel
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint
import com.facebook.react.modules.core.DeviceEventManagerModule
import expo.modules.ExpoReactHostFactory
import expo.modules.brownfield.BrownfieldNavigationState

class ReactNativeHostManager {
  companion object {
    val shared: ReactNativeHostManager by lazy { ReactNativeHostManager() }
    private var reactHost: ReactHost? = null
  }

  fun getReactHost(): ReactHost? {
    return reactHost
  }

  fun initialize(application: Application) {
    if (reactHost != null) {
      return
    }

    // Ensure that `index.android.bundle` is available in the assets
    // for release builds
    if (!BuildConfig.DEBUG) {
      val assets = application.applicationContext.assets.list("")?.toList()
        ?: emptyList<String>()
      if (!assets.contains("index.android.bundle")) {
        val bundleList = assets
          .filter { it.endsWith(".bundle") }
          .map { "- $it" }.joinToString("\n")
          ?: "None"

          throw IllegalStateException("""
          Cannot find `index.android.bundle` in the assets
          Available JS bundles:
          $bundleList
          """.trimIndent()
        )
      }
    }

    DefaultNewArchitectureEntryPoint.releaseLevel =
        try {
          ReleaseLevel.valueOf(BuildConfig.REACT_NATIVE_RELEASE_LEVEL.uppercase())
        } catch (e: IllegalArgumentException) {
          ReleaseLevel.STABLE
        }
    loadReactNative(application)
    BrownfieldLifecycleDispatcher.onApplicationCreate(application)

    // ReactBuildConfig.DEBUG is always false in the pre-built react-android AAR (library
    // BuildConfig.DEBUG is never set to true in a pre-compiled artifact). Pass the brownfield
    // module's own BuildConfig.DEBUG so Metro dev mode is active on debug builds.
    reactHost = ExpoReactHostFactory.getDefaultReactHost(
      context = application.applicationContext,
      packageList = PackageList(application).packages,
      useDevSupport = BuildConfig.DEBUG
    )
  }
}

fun Activity.showReactNativeFragment() {
  ReactNativeHostManager.shared.initialize(this.application)
  val fragment = ReactNativeFragment.createFragmentHost(this)
  setContentView(fragment)
  setUpNativeBackHandling()
}

fun Activity.setUpNativeBackHandling() {
  val componentActivity = this as? ComponentActivity
  if (componentActivity == null) {
    return
  }

  val backCallback =
      object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
          if (BrownfieldNavigationState.nativeBackEnabled) {
            isEnabled = false
            componentActivity.onBackPressedDispatcher?.onBackPressed()
            isEnabled = true
          } else {
            val reactHost = ReactNativeHostManager.shared.getReactHost()
            reactHost?.currentReactContext?.let { reactContext ->
              val deviceEventManager =
                  reactContext.getNativeModule(DeviceEventManagerModule::class.java)
              deviceEventManager?.emitHardwareBackPressed()
            }
          }
        }
      }

  componentActivity.onBackPressedDispatcher?.addCallback(componentActivity, backCallback)
}
