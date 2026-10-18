package com.alloop.hardware.aizo

import com.alloop.hardware.api.HardwareConnectionState
import com.alloop.hardware.api.HardwareDescriptor
import com.alloop.hardware.api.HardwareDevice
import com.alloop.hardware.api.HardwareEvent
import com.alloop.hardware.api.HardwareKind
import com.alloop.hardware.api.HealthMetric
import com.alloop.hardware.api.HistoryRequest
import com.alloop.hardware.api.RingHardware
import com.alloop.hardware.api.RingMeasurementRequest
import com.alloop.hardware.api.VitalReading
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

/**
 * AIZO ring adapter. It deliberately only knows [AizoRingSdkPort], keeping
 * ServiceSdkCommandV2 and its AARs out of both host applications' UI layers.
 */
class AizoRingAdapter(private val sdk: AizoRingSdkPort) : RingHardware {
    override val descriptor = HardwareDescriptor(
        kind = HardwareKind.AIZO_RING,
        displayName = "AIZO 智能戒指",
        supportedMetrics = setOf(HealthMetric.HEART_RATE, HealthMetric.SPO2, HealthMetric.BREATHING_RATE,
            HealthMetric.TEMPERATURE, HealthMetric.ECG, HealthMetric.PPG),
        supportsHistory = true,
    )
    override val connection: StateFlow<HardwareConnectionState> = sdk.connection
    override val events: Flow<HardwareEvent> = sdk.events
    override val vitalReadings: Flow<VitalReading> = sdk.vitalReadings

    override suspend fun scan(timeoutMillis: Long) = sdk.scan(timeoutMillis)
    override suspend fun connect(device: HardwareDevice) = sdk.connect(device)
    override suspend fun disconnect() = sdk.disconnect()
    override suspend fun startMeasurement(request: RingMeasurementRequest) = sdk.startMeasurement(request)
    override suspend fun stopMeasurement() = sdk.stopMeasurement()
    override suspend fun syncHistory(request: HistoryRequest) = sdk.syncHistory(request)
}

/** Vendor binding implemented once per app; map it to ServiceSdkCommandV2. */
interface AizoRingSdkPort {
    val connection: StateFlow<HardwareConnectionState>
    val events: Flow<HardwareEvent>
    val vitalReadings: Flow<VitalReading>
    suspend fun scan(timeoutMillis: Long): List<HardwareDevice>
    suspend fun connect(device: HardwareDevice)
    suspend fun disconnect()
    suspend fun startMeasurement(request: RingMeasurementRequest)
    suspend fun stopMeasurement()
    suspend fun syncHistory(request: HistoryRequest)
}
