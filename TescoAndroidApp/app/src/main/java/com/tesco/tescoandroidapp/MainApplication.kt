package com.tesco.tescoandroidapp

import android.app.Application
import android.content.res.Configuration
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.BrownfieldLifecycleDispatcher
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.ReactNativeHostManager

/**
 * Native consumer application — mirrors TescoUIKitApp's AppDelegate on iOS.
 *
 * Initialises the React Native host eagerly in onCreate so the first RN surface
 * renders without cold-start latency. In a flagged rollout, move this call behind
 * a feature flag to achieve zero cost for users who never see RN.
 */
class MainApplication : Application() {

  override fun onCreate() {
    super.onCreate()
    // Initialise the React Native runtime. Idempotent — safe to call multiple times.
    ReactNativeHostManager.shared.initialize(this)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    BrownfieldLifecycleDispatcher.onConfigurationChanged(this, newConfig)
  }
}
