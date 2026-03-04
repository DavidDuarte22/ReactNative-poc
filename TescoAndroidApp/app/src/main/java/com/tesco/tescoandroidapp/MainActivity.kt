package com.tesco.tescoandroidapp

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.BrownfieldActivity

/**
 * Entry-point Activity — mirrors TescoUIKitApp's root UIViewController on iOS.
 *
 * Extends BrownfieldActivity (AppCompatActivity + onConfigurationChanged forwarding)
 * so the embedded RN surface receives lifecycle events correctly.
 */
class MainActivity : BrownfieldActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    setContent {
      HomeScreen()
    }
  }
}
