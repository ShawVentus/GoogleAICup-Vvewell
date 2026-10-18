package com.alloop.hardware.alloopring

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

/** Adapter for the Alloop Core ring SDK (`com.alloop.core.api.AlloopCore`). */
class AlloopRingAdapter(private val sdk: AlloopRingSdkPort) : RingHardware {
    override val descriptor = HardwareDescriptor(
        kind = HardwareKind.ALLOOP_RING,
        displayName = "Alloop 智能戒指",
        supportedMetrics = setOf(HealthMetric.HEART_RATE, HealthMetric.SPO2, HealthMetric.PPG, HealthMetric.ACCELERATION),
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

/** Vendor binding implemented with the AlloopCore callbacks, never from UI code. */
interface AlloopRingSdkPort {
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
