package com.alloop.hardware.xiaozhi

import com.alloop.hardware.api.HardwareConnectionState
import com.alloop.hardware.api.HardwareDescriptor
import com.alloop.hardware.api.HardwareDevice
import com.alloop.hardware.api.HardwareEvent
import com.alloop.hardware.api.HardwareKind
import com.alloop.hardware.api.UnifiedHardware
import com.alloop.hardware.api.VitalReading
import com.alloop.hardware.api.XiaoZhiHardware
import com.alloop.hardware.api.XiaoZhiMessage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

/** XiaoZhi control adapter. Health values remain available through the common
 * contract but are empty unless a firmware MCP tool explicitly supplies them. */
class XiaoZhiAdapter(private val sdk: XiaoZhiSdkPort) : XiaoZhiHardware {
    override val descriptor = HardwareDescriptor(HardwareKind.XIAOZHI, "小智 BLE 设备")
    override val connection: StateFlow<HardwareConnectionState> = sdk.connection
    override val events: Flow<HardwareEvent> = sdk.events
    override val vitalReadings: Flow<VitalReading> = sdk.vitalReadings
    override val messages: Flow<XiaoZhiMessage> = sdk.messages

    override suspend fun scan(timeoutMillis: Long) = sdk.scan(timeoutMillis)
    override suspend fun connect(device: HardwareDevice) = sdk.connect(device)
    override suspend fun disconnect() = sdk.disconnect()
    override suspend fun configureWifi(ssid: String, password: String) = sdk.configureWifi(ssid, password)
    override suspend fun sendCommand(command: String, parametersJson: String) = sdk.sendCommand(command, parametersJson)
    override suspend fun initializeMcp(requestId: Int) = sdk.initializeMcp(requestId)
    override suspend fun listMcpTools(requestId: Int, withUserTools: Boolean) = sdk.listMcpTools(requestId, withUserTools)
    override suspend fun callMcpTool(name: String, argumentsJson: String, requestId: Int) =
        sdk.callMcpTool(name, argumentsJson, requestId)
}

interface XiaoZhiSdkPort {
    val connection: StateFlow<HardwareConnectionState>
    val events: Flow<HardwareEvent>
    val vitalReadings: Flow<VitalReading>
    val messages: Flow<XiaoZhiMessage>
    suspend fun scan(timeoutMillis: Long): List<HardwareDevice>
    suspend fun connect(device: HardwareDevice)
    suspend fun disconnect()
    suspend fun configureWifi(ssid: String, password: String)
    suspend fun sendCommand(command: String, parametersJson: String)
    suspend fun initializeMcp(requestId: Int)
    suspend fun listMcpTools(requestId: Int, withUserTools: Boolean)
    suspend fun callMcpTool(name: String, argumentsJson: String, requestId: Int)
}
