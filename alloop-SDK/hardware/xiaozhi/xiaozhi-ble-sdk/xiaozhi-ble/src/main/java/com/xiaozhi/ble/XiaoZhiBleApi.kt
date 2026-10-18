package com.xiaozhi.ble

import android.Manifest
import android.os.Build
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/** Stable API exposed to Android apps, independent of their target SDK. */
interface XiaoZhiBleClient {
    val connection: StateFlow<XiaoZhiConnectionState>
    val events: SharedFlow<XiaoZhiBleEvent>

    /** Returns nearby devices after [timeoutMillis]. The default scan is intentionally unfiltered. */
    suspend fun scan(timeoutMillis: Long = 6_000): List<XiaoZhiDevice>

    /** Stops an in-progress scan and returns control to the host immediately. */
    suspend fun stopScan()

    /** Connects, requests Just Works bonding, discovers services, and subscribes to all response channels. */
    suspend fun connect(device: XiaoZhiDevice)

    suspend fun disconnect()
    suspend fun readDeviceStatus(): XiaoZhiJsonPayload
    suspend fun readSystemInfo(): XiaoZhiJsonPayload
    suspend fun readWifiStatus(): XiaoZhiJsonPayload
    suspend fun configureWifi(ssid: String, password: String)
    suspend fun sendCommand(command: String, paramsJson: String = "{}")
    suspend fun initializeMcp(requestId: Int = 1)
    suspend fun listMcpTools(requestId: Int = 2, withUserTools: Boolean = true)
    suspend fun callMcpTool(name: String, argumentsJson: String = "{}", requestId: Int = 3)
    suspend fun sendMcpRequest(requestJson: String)
}

data class XiaoZhiDevice(
    val address: String,
    val name: String?,
    val rssi: Int,
)

sealed interface XiaoZhiConnectionState {
    data object Disconnected : XiaoZhiConnectionState
    data class Connecting(val address: String) : XiaoZhiConnectionState
    data class Pairing(val address: String) : XiaoZhiConnectionState
    data class Ready(val device: XiaoZhiDevice, val mtu: Int) : XiaoZhiConnectionState
    data class Failed(val message: String) : XiaoZhiConnectionState
}

sealed interface XiaoZhiBleEvent {
    data class DeviceStatus(val payload: XiaoZhiJsonPayload) : XiaoZhiBleEvent
    data class CommandResponse(val payload: XiaoZhiJsonPayload) : XiaoZhiBleEvent
    data class McpResponse(val response: XiaoZhiMcpResponse) : XiaoZhiBleEvent
    data class ConnectionLost(val reason: String) : XiaoZhiBleEvent
}

data class XiaoZhiJsonPayload(val raw: String) {
    fun requireObject(): String {
        require(raw.trimStart().startsWith("{")) { "Expected a JSON object: $raw" }
        return raw
    }
}

data class XiaoZhiMcpResponse(val messageId: Int, val rawJson: String)

/** The host app owns runtime permission requests; this object keeps SDK branching in one place. */
object XiaoZhiBlePermissions {
    fun requiredForScan(): Array<String> = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> arrayOf(Manifest.permission.BLUETOOTH_SCAN)
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        else -> emptyArray()
    }

    fun requiredForConnection(): Array<String> = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
        else -> emptyArray()
    }

    fun requiredForFullUse(): Array<String> = (requiredForScan() + requiredForConnection()).distinct().toTypedArray()
}
