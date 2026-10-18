package com.alloop.hardware.radar

import com.alloop.hardware.api.HardwareConnectionState
import com.alloop.hardware.api.HardwareDescriptor
import com.alloop.hardware.api.HardwareDevice
import com.alloop.hardware.api.HardwareEvent
import com.alloop.hardware.api.HardwareKind
import com.alloop.hardware.api.HealthMetric
import com.alloop.hardware.api.PointCloudFrame
import com.alloop.hardware.api.RadarConfig
import com.alloop.hardware.api.RadarHardware
import com.alloop.hardware.api.VitalReading
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

/** Adapter for the MRS6130-P1812 / JDY-23 radar bridge. */
class MmWaveRadarAdapter(private val sdk: MmWaveRadarSdkPort) : RadarHardware {
    override val descriptor = HardwareDescriptor(
        kind = HardwareKind.MMWAVE_RADAR,
        displayName = "毫米波雷达",
        supportedMetrics = setOf(HealthMetric.HEART_RATE, HealthMetric.BREATHING_RATE),
    )
    override val connection: StateFlow<HardwareConnectionState> = sdk.connection
    override val events: Flow<HardwareEvent> = sdk.events
    override val vitalReadings: Flow<VitalReading> = sdk.vitalReadings
    override val pointCloudFrames: Flow<PointCloudFrame> = sdk.pointCloudFrames

    override suspend fun scan(timeoutMillis: Long) = sdk.scan(timeoutMillis)
    override suspend fun connect(device: HardwareDevice) = sdk.connect(device)
    override suspend fun disconnect() = sdk.disconnect()
    override suspend fun configure(config: RadarConfig) = sdk.configure(config)
    override suspend fun startRadar() = sdk.startRadar()
    override suspend fun stopRadar() = sdk.stopRadar()
}

interface MmWaveRadarSdkPort {
    val connection: StateFlow<HardwareConnectionState>
    val events: Flow<HardwareEvent>
    val vitalReadings: Flow<VitalReading>
    val pointCloudFrames: Flow<PointCloudFrame>
    suspend fun scan(timeoutMillis: Long): List<HardwareDevice>
    suspend fun connect(device: HardwareDevice)
    suspend fun disconnect()
    suspend fun configure(config: RadarConfig)
    suspend fun startRadar()
    suspend fun stopRadar()
}
