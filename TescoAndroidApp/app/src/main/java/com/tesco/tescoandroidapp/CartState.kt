package com.tesco.tescoandroidapp

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.parser.rnpoc.ReactNativePoC.brownfield.brownfield.BridgeEvents
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Mirrors iOS CartState.swift (ObservableObject + @Published var cartCount).
 *
 * Subscribes to BridgeEvents.buttonTapped — the SharedFlow that is emitted
 * whenever the RN surface sends { event: "buttonTapped" } via BrownfieldMessaging.
 *
 * The ViewModel survives configuration changes; the Compose UI observes
 * [cartCount] as a StateFlow to update the cart badge reactively.
 */
class CartState : ViewModel() {

  private val _cartCount = MutableStateFlow(0)
  val cartCount: StateFlow<Int> = _cartCount.asStateFlow()

  init {
    viewModelScope.launch {
      BridgeEvents.buttonTapped.collect {
        _cartCount.value++
      }
    }
  }
}
