package com.parser.rnpoc.ReactNativePoC.brownfield.brownfield

import android.app.Application
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatActivity
import com.facebook.react.modules.core.DefaultHardwareBackBtnHandler
import expo.modules.ApplicationLifecycleDispatcher

object BrownfieldLifecycleDispatcher {
  fun onApplicationCreate(application: Application) {
    ApplicationLifecycleDispatcher.onApplicationCreate(application)
  }

  fun onConfigurationChanged(application: Application, newConfig: Configuration) {
    ApplicationLifecycleDispatcher.onConfigurationChanged(application, newConfig)
  }
}

open class BrownfieldActivity : AppCompatActivity(), DefaultHardwareBackBtnHandler {

  // Required by ReactDelegate.onHostResume() — invoked when RN wants the OS default back action.
  override fun invokeDefaultOnBackPressed() {
    onBackPressedDispatcher.onBackPressed()
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    BrownfieldLifecycleDispatcher.onConfigurationChanged(this.application, newConfig)
  }
}
