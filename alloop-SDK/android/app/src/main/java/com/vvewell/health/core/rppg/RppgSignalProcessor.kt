package com.vvewell.health.core.rppg

data class TimedRppgSample(
    val timestampSeconds: Double,
    val value: Double,
)

data class RppgResult(
    val heartRateBpm: Double,
    val signalQuality: Double,
    val rmssdMs: Double?,
    val sampleCount: Int,
)

enum class SignalConfidence {
    Low,
    Medium,
    High,
}

data class RespirationResult(
    val breathsPerMinute: Double,
    val signalQuality: Double,
    val confidence: SignalConfidence,
    val sampleCount: Int,
    val windowSeconds: Double,
)

typealias RppgAnalysisRejectionReason = MetricRejectionReason

data class RppgAnalysisAttempt<T>(
    val result: T?,
    val rejectionReason: RppgAnalysisRejectionReason?,
    val durationSeconds: Double?,
    val effectiveSampleRateHz: Double?,
    val maximumGapSeconds: Double?,
)

/** Shared HR/RR post-processing over one continuous, timestamped BVP segment. */
class RppgSignalProcessor internal constructor(
    private val heartRateEstimator: RppgHeartRateEstimator = RppgHeartRateEstimator(),
    private val respirationEstimator: RppgRespirationEstimator = RppgRespirationEstimator(),
) {
    fun beginSegment(segmentId: Long) {
        heartRateEstimator.beginSegment(segmentId)
        respirationEstimator.beginSegment(segmentId)
    }

    fun clearMetricHistory() {
        heartRateEstimator.clearHistory()
        respirationEstimator.clearHistory()
    }

    fun analyze(samples: List<Double>, sampleRateHz: Double): RppgResult? {
        if (sampleRateHz <= 0.0) return null
        return analyzeTimed(
            samples.mapIndexed { index, value -> TimedRppgSample(index / sampleRateHz, value) },
        )
    }

    fun analyzeTimed(samples: List<TimedRppgSample>): RppgResult? =
        analyzeHeartRateMetric(samples).toHeartRateResult()

    fun analyzeHeartRateMetric(
        samples: List<TimedRppgSample>,
        segmentId: Long = 0L,
    ): MetricEstimate = heartRateEstimator.estimate(samples, segmentId)

    fun analyzeTimedWithDiagnostics(samples: List<TimedRppgSample>): RppgAnalysisAttempt<RppgResult> =
        analyzeHeartRateMetric(samples).toAttempt(MetricEstimate::toHeartRateResult)

    fun analyzeRespirationMetric(
        samples: List<TimedRppgSample>,
        segmentId: Long = 0L,
    ): MetricEstimate = respirationEstimator.estimate(samples, segmentId)

    fun analyzeRespirationTimed(samples: List<TimedRppgSample>): RespirationResult? =
        analyzeRespirationMetric(samples).toRespirationResult()

    fun analyzeRespirationTimedWithDiagnostics(
        samples: List<TimedRppgSample>,
    ): RppgAnalysisAttempt<RespirationResult> =
        analyzeRespirationMetric(samples).toAttempt(MetricEstimate::toRespirationResult)
}

internal fun MetricEstimate.toHeartRateResult(): RppgResult? {
    if (!available || type != RppgMetricType.HeartRate) return null
    return RppgResult(
        heartRateBpm = requireNotNull(value),
        signalQuality = diagnostics.signalQuality ?: confidence,
        rmssdMs = diagnostics.rmssdMs,
        sampleCount = diagnostics.sampleCount,
    )
}

internal fun MetricEstimate.toRespirationResult(): RespirationResult? {
    if (!available || type != RppgMetricType.RespirationRate) return null
    return RespirationResult(
        breathsPerMinute = requireNotNull(value),
        signalQuality = confidence,
        confidence = when {
            confidence >= RppgConfidencePolicy.HIGH_CONFIDENCE_THRESHOLD -> SignalConfidence.High
            confidence >= 0.4 -> SignalConfidence.Medium
            else -> SignalConfidence.Low
        },
        sampleCount = diagnostics.sampleCount,
        windowSeconds = diagnostics.durationSeconds ?: 0.0,
    )
}

private fun <T> MetricEstimate.toAttempt(converter: MetricEstimate.() -> T?): RppgAnalysisAttempt<T> =
    RppgAnalysisAttempt(
        result = converter(),
        rejectionReason = rejectionReason,
        durationSeconds = diagnostics.durationSeconds,
        effectiveSampleRateHz = diagnostics.targetSampleRateHz,
        maximumGapSeconds = diagnostics.maximumGapSeconds,
    )

interface RppgInferenceEngine : AutoCloseable {
    /**
     * Accepts a 36×36 RGB face crop normalized to 0–1.
     * Returns one BVP sample while retaining recurrent model state internally.
     */
    fun processFrame(rgb: FloatArray, frameDeltaSeconds: Float): Float
    fun reset()
}
