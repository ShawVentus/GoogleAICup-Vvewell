package com.alloop.hardware.api

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

/**
 * Application-facing contract shared by all four Bluetooth hardware types.
 *
 * This file has no Android or vendor-SDK dependency. Keep vendor protocols in
 * the adapter folders so either host SDK can reuse the same application API.
 */
interface UnifiedHardware {
    val descriptor: HardwareDescriptor
    val connection: StateFlow<HardwareConnectionState>
    val events: Flow<HardwareEvent>

    /** Always present. Unsupported metrics are null and declared by [descriptor]. */
    val vitalReadings: Flow<VitalReading>

    suspend fun scan(timeoutMillis: Long = 6_000): List<HardwareDevice>
    suspend fun connect(device: HardwareDevice)
    suspend fun disconnect()
}

interface RingHardware : UnifiedHardware {
    suspend fun startMeasurement(request: RingMeasurementRequest)
    suspend fun stopMeasurement()
    suspend fun syncHistory(request: HistoryRequest = HistoryRequest())
}

interface RadarHardware : UnifiedHardware {
    val pointCloudFrames: Flow<PointCloudFrame>
    suspend fun configure(config: RadarConfig)
    suspend fun startRadar()
    suspend fun stopRadar()
}

interface XiaoZhiHardware : UnifiedHardware {
    val messages: Flow<XiaoZhiMessage>
    suspend fun configureWifi(ssid: String, password: String)
    suspend fun sendCommand(command: String, parametersJson: String = "{}")
    suspend fun initializeMcp(requestId: Int = 1)
    suspend fun listMcpTools(requestId: Int = 2, withUserTools: Boolean = true)
    suspend fun callMcpTool(name: String, argumentsJson: String = "{}", requestId: Int = 3)
}

enum class HardwareKind { AIZO_RING, ALLOOP_RING, XIAOZHI, MMWAVE_RADAR }
enum class HardwareConnectionState { DISCONNECTED, SCANNING, CONNECTING, PAIRING, READY, ERROR }
enum class HealthMetric { HEART_RATE, SPO2, BREATHING_RATE, TEMPERATURE, ECG, PPG, ACCELERATION }

data class HardwareDescriptor(
    val kind: HardwareKind,
    val displayName: String,
    val supportedMetrics: Set<HealthMetric> = emptySet(),
    val supportsHistory: Boolean = false,
)

data class HardwareDevice(
    val id: String,
    val name: String? = null,
    val rssi: Int? = null,
    val transportData: Any? = null,
)

data class VitalReading(
    val source: HardwareKind,
    val timestampEpochMillis: Long = System.currentTimeMillis(),
    val heartRateBpm: Double? = null,
    val spo2Percent: Double? = null,
    val breathingRateBpm: Double? = null,
    val temperatureCelsius: Double? = null,
    val confidence: Double? = null,
    val raw: Map<String, Any?> = emptyMap(),
)

data class RingMeasurementRequest(
    val metrics: Set<HealthMetric>,
    val continuous: Boolean = false,
)

data class HistoryRequest(
    val metrics: Set<HealthMetric> = emptySet(),
    val fromEpochMillis: Long? = null,
    val toEpochMillis: Long? = null,
)

data class RadarConfig(
    val includeVitalPhase: Boolean = true,
    val includePointCloud: Boolean = true,
    val automaticVitalBin: Boolean = true,
    val selectedBin: Int = 25,
    val minBin: Int = 10,
    val maxBin: Int = 100,
)

data class PointCloudFrame(
    val frameIndex: Long,
    val points: List<PointCloudPoint>,
)

data class PointCloudPoint(
    val xMeters: Double,
    val yMeters: Double,
    val zMeters: Double,
    val velocityMetersPerSecond: Double,
    val snrDb: Double,
    val trackId: Int,
    val isStatic: Boolean,
)

sealed interface HardwareEvent {
    data class Status(val message: String) : HardwareEvent
    data class Error(val code: String, val cause: Throwable? = null) : HardwareEvent
    data class History(val payload: Map<String, Any?>) : HardwareEvent
}

sealed interface XiaoZhiMessage : HardwareEvent {
    data class DeviceStatus(val rawJson: String) : XiaoZhiMessage
    data class CommandResponse(val rawJson: String) : XiaoZhiMessage
    data class McpResponse(val requestId: Int, val rawJson: String) : XiaoZhiMessage
}
