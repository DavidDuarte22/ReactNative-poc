package com.tesco.tescoandroidapp

import android.os.Bundle
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.ReactNativeViewFactory
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.RootComponent

private val TescoBlue = Color(0xFF00539F)
private val TescoRed = Color(0xFFCC0000)

/**
 * Home screen — mirrors the iOS HomeView (SwiftUI) in TescoUIKitApp.
 *
 * Layout:
 *   ┌─────────────────────────────────┐
 *   │  Tesco           🛒 [badge]     │  ← Native Compose top bar
 *   ├─────────────────────────────────┤
 *   │  Native Compose description     │
 *   ├─────────────────────────────────┤
 *   │                                 │
 *   │       React Native Surface      │  ← AndroidView wrapping ReactRootView
 *   │  (button → BrownfieldMessaging) │
 *   │                                 │
 *   └─────────────────────────────────┘
 *
 * When the user taps "Call Native" in the RN surface:
 *   JS sendMessage({ event: "buttonTapped" })
 *     → BridgeEvents.buttonTapped SharedFlow
 *       → CartState.cartCount++
 *         → badge re-renders
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(cartState: CartState = viewModel()) {
  val cartCount by cartState.cartCount.collectAsState()
  val activity = LocalContext.current as FragmentActivity

  Column(modifier = Modifier.fillMaxSize()) {

    // Native Compose top bar — persists across RN navigations
    TopAppBar(
      title = {
        Text(
          text = "Tesco",
          fontWeight = FontWeight.Bold,
          color = TescoBlue,
          fontSize = 20.sp,
        )
      },
      actions = {
        CartBadge(count = cartCount)
        Spacer(modifier = Modifier.width(12.dp))
      },
      colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White),
    )

    // Native description row — owned by the host app
    Surface(color = Color.White) {
      Text(
        text = "Tap the button inside the React Native surface to add to cart.",
        style = MaterialTheme.typography.bodyMedium,
        color = Color(0xFF555555),
        modifier = Modifier
          .fillMaxWidth()
          .padding(horizontal = 16.dp, vertical = 12.dp),
      )
    }
    HorizontalDivider()

    // React Native surface — embedded via AndroidView + ReactDelegate
    val launchOptions = remember {
      Bundle().apply {
        putString("userId", "android-user-001")
        putString("locale", "en-GB")
      }
    }
    AndroidView(
      modifier = Modifier.fillMaxSize(),
      factory = { _ ->
        ReactNativeViewFactory.createFrameLayout(
          context = activity,
          activity = activity,
          rootComponent = RootComponent.TescoRNApp,
          launchOptions = launchOptions,
        )
      },
    )
  }
}

@Composable
private fun CartBadge(count: Int) {
  Box(contentAlignment = Alignment.Center) {
    Text(text = "🛒", fontSize = 26.sp)
    if (count > 0) {
      Box(
        modifier = Modifier
          .size(18.dp)
          .clip(CircleShape)
          .background(TescoRed)
          .align(Alignment.TopEnd),
        contentAlignment = Alignment.Center,
      ) {
        Text(
          text = if (count > 99) "99+" else count.toString(),
          color = Color.White,
          fontSize = 10.sp,
          fontWeight = FontWeight.Bold,
        )
      }
    }
  }
}
