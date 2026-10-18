package com.alloop.radar.bridge

/** Connection state reported by the transport and the bridge. */
enum class RadarConnectionState {
    DISCONNECTED,
    CONNECTING,
    DISCOVERING,
    ENABLING_NOTIFICATIONS,
    READY,
    DISCONNECTING,
    ERROR
}

/** VitalBridge output flags. */
object RadarOutputFlags {
    const val NONE: Int = 0
    const val VITAL_PHASE: Int = 0x01
    const val POINT_CLOUD: Int = 0x02
}

enum class VitalBinMode { AUTO_STRONGEST, MANUAL }

data class VitalConfig(
    val outputFlags: Int = RadarOutputFlags.VITAL_PHASE or RadarOutputFlags.POINT_CLOUD,
    val binMode: VitalBinMode = VitalBinMode.AUTO_STRONGEST,
    val selectedBin: Int = 25,
    val minBin: Int = 10,
    val maxBin: Int = 100
) {
    init {
        require(outputFlags and 0xFC == 0) { "Unknown VitalBridge output flag" }
        require(selectedBin in 0..0xFFFF)
        require(minBin in 0..0xFFFF)
        require(maxBin in 0..0xFFFF)
        require(minBin <= maxBin) { "minBin must not exceed maxBin" }
    }
}

data class VitalSample(
    val protocolVersion: Int,
    val flags: Int,
    val rangeBin: Int,
    val frameIndex: Long,
    val imag: Short,
    val real: Short,
    val magnitudeSquared: Long,
    val rangeResolutionMm: Int,
    val samplePeriodMs: Int
) {
    val distanceMeters: Double
        get() = rangeBin * rangeResolutionMm / 1000.0

    /** Wrapped phase in radians. Use VitalEstimator for unwrapped phase. */
    val phaseRadians: Double
        get() = kotlin.math.atan2(imag.toDouble(), real.toDouble())
}

data class PointCloudPoint(
    val xMeters: Double,
    val yMeters: Double,
    val zMeters: Double,
    val velocityMetersPerSecond: Double,
    val snrDb: Double,
    val trackId: Int,
    val isStatic: Boolean
)

data class PointCloudFrame(
    val frameIndex: Long,
    val frameWords: Long,
    val offset: Long,
    val points: List<PointCloudPoint>
)

data class VitalMetrics(
    val breathingBpm: Double?,
    val heartBpm: Double?,
    val breathingConfidence: Double,
    val heartConfidence: Double,
    val windowSeconds: Double,
    val distanceMeters: Double
)

data class HifResponse(
    val messageId: Int,
    val status: Int,
    val payload: ByteArray
) {
    val isSuccess: Boolean get() = status == 0
}

/** Optional raw frame for applications that need vendor-specific message IDs. */
data class HifFrame(
    val type: Int,
    val flags: Int,
    val messageId: Int,
    val sequence: Int,
    val payload: ByteArray,
    val raw: ByteArray
)

interface RadarListener {
    fun onStateChanged(state: RadarConnectionState) {}
    fun onHifResponse(response: HifResponse) {}
    fun onPointCloud(frame: PointCloudFrame) {}
    fun onVitalSample(sample: VitalSample) {}
    fun onVitalMetrics(metrics: VitalMetrics) {}
    fun onRawHifFrame(frame: HifFrame) {}
    fun onProtocolError(message: String) {}
    fun onTransportError(error: Throwable) {}
}
