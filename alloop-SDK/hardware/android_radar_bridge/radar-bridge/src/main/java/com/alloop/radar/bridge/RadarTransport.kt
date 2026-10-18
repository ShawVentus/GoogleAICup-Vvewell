package com.alloop.radar.bridge

import android.bluetooth.BluetoothDevice

/**
 * BLE-independent transport contract. Implement this interface when an app
 * already uses Nordic, RxAndroidBle, Kable, BLESSED, or another BLE SDK.
 */
interface RadarTransport {
    val state: RadarConnectionState

    fun setListener(listener: Listener?)
    fun connect(device: BluetoothDevice)
    fun disconnect()

    /** Queues one or more bytes for the radar HIF UART characteristic. */
    fun write(bytes: ByteArray): Boolean

    interface Listener {
        fun onStateChanged(state: RadarConnectionState)
        fun onBytesReceived(bytes: ByteArray)
        fun onError(error: Throwable)
    }
}
