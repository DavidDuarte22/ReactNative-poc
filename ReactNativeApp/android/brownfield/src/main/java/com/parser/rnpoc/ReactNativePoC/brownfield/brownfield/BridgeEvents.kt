package com.parser.rnpoc.ReactNativePoC.brownfield.brownfield

import expo.modules.brownfield.BrownfieldMessaging
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Typed Kotlin events forwarded from the RN layer via BrownfieldMessaging.
 *
 * Mirrors iOS BridgeEvents.swift (Combine publishers over NotificationCenter).
 * Consumers subscribe to the SharedFlow properties; the BrownfieldMessaging
 * transport is an internal implementation detail of this library.
 *
 * Usage (from consumer app ViewModel):
 *   viewModelScope.launch { BridgeEvents.buttonTapped.collect { /* increment counter */ } }
 */
object BridgeEvents {
  private val _buttonTapped = MutableSharedFlow<Unit>(extraBufferCapacity = 16)
  val buttonTapped: SharedFlow<Unit> = _buttonTapped.asSharedFlow()

  init {
    BrownfieldMessaging.addListener { message ->
      if (message["event"] == "buttonTapped") {
        _buttonTapped.tryEmit(Unit)
      }
    }
  }
}
