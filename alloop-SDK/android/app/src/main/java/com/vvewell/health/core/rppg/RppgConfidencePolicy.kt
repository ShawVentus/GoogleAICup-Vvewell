package com.vvewell.health.core.rppg

/**
 * Presentation policy for the heuristic metric confidence scores. These values
 * are quality scores, not calibrated probabilities.
 */
internal object RppgConfidencePolicy {
    const val HIGH_CONFIDENCE_THRESHOLD = 0.7

    fun labelFor(estimate: MetricEstimate?): RppgConfidenceLabel? = when {
        estimate == null || !estimate.available -> null
        estimate.confidence >= HIGH_CONFIDENCE_THRESHOLD -> RppgConfidenceLabel.HighConfidence
        else -> RppgConfidenceLabel.ReferenceOnly
    }

    /**
     * Conservative aggregate of the currently available metric confidences.
     * It deliberately does not use the HR autocorrelation SQI diagnostic.
     */
    fun conservativeAggregateQuality(
        heartRate: MetricEstimate?,
        respiration: MetricEstimate?,
    ): Double {
        val confidences = listOfNotNull(
            heartRate.availableConfidenceOrNull(),
            respiration.availableConfidenceOrNull(),
        )
        return (confidences.minOrNull() ?: 0.0).coerceIn(0.0, 1.0)
    }

    private fun MetricEstimate?.availableConfidenceOrNull(): Double? =
        takeIf { it?.available == true }
            ?.confidence
            ?.takeIf(Double::isFinite)
            ?.coerceIn(0.0, 1.0)
}

internal enum class RppgConfidenceLabel {
    HighConfidence,
    ReferenceOnly,
}
