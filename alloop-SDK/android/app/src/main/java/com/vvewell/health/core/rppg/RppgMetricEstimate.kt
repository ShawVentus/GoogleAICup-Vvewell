package com.vvewell.health.core.rppg

enum class RppgMetricType {
    HeartRate,
    RespirationRate,
}

enum class MetricRejectionReason {
    NonFiniteInput,
    NonIncreasingTimestamp,
    ExcessiveLocalGap,
    InsufficientDuration,
    InsufficientSamples,
    SampleRateTooLow,
    LowSignalEnergy,
    FilterFailure,
    NoSpectralPeak,
    NoRespiratoryBandBin,
    NoRespiratoryPeak,
    WeakRespiratoryPeak,
    EmdFailure,
    EmdDidNotConverge,
    NoPhysiologicalImf,
    InsufficientInstantaneousFrequency,
    InsufficientPhysiologicalCycles,
    NumericalFailure,
}

data class MetricDiagnostics(
    val sampleCount: Int = 0,
    val durationSeconds: Double? = null,
    val medianSampleRateHz: Double? = null,
    val spanSampleRateHz: Double? = null,
    val targetSampleRateHz: Double? = null,
    val medianGapSeconds: Double? = null,
    val maximumGapSeconds: Double? = null,
    val allowedGapSeconds: Double? = null,
    val timeQuality: Double? = null,
    val frequencyResolutionHz: Double? = null,
    val peakFrequencyHz: Double? = null,
    val peakPower: Double? = null,
    val meanBandPower: Double? = null,
    val peakToMeanRatio: Double? = null,
    val prominence: Double? = null,
    val concentration: Double? = null,
    val physiologicalCycles: Double? = null,
    val historyQuality: Double? = null,
    val rawConfidence: Double? = null,
    val signalQuality: Double? = null,
    val rmssdMs: Double? = null,
    val filterLowHz: Double? = null,
    val filterHighHz: Double? = null,
    val physiologicalLowHz: Double? = null,
    val physiologicalHighHz: Double? = null,
    val imfCount: Int? = null,
    val selectedImfIndex: Int? = null,
    val selectedImfEnergy: Double? = null,
    val totalImfEnergy: Double? = null,
    val validInstantaneousFrequencyCount: Int? = null,
    val cleanedInstantaneousFrequencyCount: Int? = null,
    val minimumCleanedFrequencyCount: Int? = null,
    val autocorrelationPeakLag: Int? = null,
    val autocorrelationPeakBpm: Double? = null,
    val emdSiftIterations: Int? = null,
    val analysisDurationMillis: Double? = null,
)

/**
 * Independent HR/RR result contract. Confidence is an explainable heuristic
 * quality score in [0, 1], not a calibrated probability.
 */
data class MetricEstimate(
    val type: RppgMetricType,
    val value: Double?,
    val rawValue: Double?,
    val confidence: Double,
    val available: Boolean,
    val rejectionReason: MetricRejectionReason?,
    val diagnostics: MetricDiagnostics,
) {
    init {
        require(confidence.isFinite() && confidence in 0.0..1.0) {
            "Metric confidence must be finite and within [0, 1]"
        }
        if (available) {
            require(value != null && rawValue != null && rejectionReason == null) {
                "Available metric must contain values and no rejection reason"
            }
            require(value.isFinite() && rawValue.isFinite()) {
                "Available metric values must be finite"
            }
        } else {
            require(value == null && rawValue == null && rejectionReason != null && confidence == 0.0) {
                "Rejected metric must contain no value, one reason, and zero confidence"
            }
        }
    }

    companion object {
        fun rejected(
            type: RppgMetricType,
            reason: MetricRejectionReason,
            diagnostics: MetricDiagnostics = MetricDiagnostics(),
        ) = MetricEstimate(
            type = type,
            value = null,
            rawValue = null,
            confidence = 0.0,
            available = false,
            rejectionReason = reason,
            diagnostics = diagnostics,
        )

        fun available(
            type: RppgMetricType,
            value: Double,
            rawValue: Double = value,
            confidence: Double,
            diagnostics: MetricDiagnostics,
        ): MetricEstimate {
            if (!value.isFinite() || !rawValue.isFinite() || !confidence.isFinite()) {
                return rejected(type, MetricRejectionReason.NumericalFailure, diagnostics)
            }
            return MetricEstimate(
                type = type,
                value = value,
                rawValue = rawValue,
                confidence = confidence.coerceIn(0.0, 1.0),
                available = true,
                rejectionReason = null,
                diagnostics = diagnostics,
            )
        }
    }
}

internal fun ramp(value: Double, low: Double, high: Double): Double {
    require(high > low) { "Ramp upper bound must exceed lower bound" }
    return ((value - low) / (high - low)).coerceIn(0.0, 1.0)
}
