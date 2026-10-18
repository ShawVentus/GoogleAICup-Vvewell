package com.vvewell.health.core.rppg

import kotlin.math.abs

internal class RppgMetricHistory(
    private val stableRelativeChange: Double = 0.10,
    private val unstableRelativeChange: Double = 0.30,
) {
    private var activeSegmentId: Long? = null
    private val rawValues = ArrayDeque<Double>()
    private var previousReportedConfidence: Double? = null

    @Synchronized
    fun beginSegment(segmentId: Long) {
        activeSegmentId = segmentId
        rawValues.clear()
        previousReportedConfidence = null
    }

    @Synchronized
    fun clear() {
        activeSegmentId = null
        rawValues.clear()
        previousReportedConfidence = null
    }

    @Synchronized
    fun historyQuality(segmentId: Long, rawValue: Double): Double {
        if (segmentId != activeSegmentId || rawValues.isEmpty()) return 0.5
        val previousMedian = median(rawValues.toDoubleArray())
        val relativeChange = abs(rawValue - previousMedian) / previousMedian.coerceAtLeast(EPSILON)
        return (
            1.0 - ramp(relativeChange, stableRelativeChange, unstableRelativeChange)
            ).coerceIn(0.0, 1.0)
    }

    @Synchronized
    fun stabilize(segmentId: Long, estimate: MetricEstimate): MetricEstimate {
        if (!estimate.available || segmentId != activeSegmentId) return estimate
        val rawValue = requireNotNull(estimate.rawValue)
        val smoothingWindow = rawValues.takeLast(MAX_HISTORY_VALUES - 1) + rawValue
        val stabilizedValue = median(smoothingWindow.toDoubleArray())
        val reportedConfidence = previousReportedConfidence?.let { previous ->
            CONFIDENCE_CURRENT_WEIGHT * estimate.confidence +
                (1.0 - CONFIDENCE_CURRENT_WEIGHT) * previous
        } ?: estimate.confidence

        rawValues.addLast(rawValue)
        while (rawValues.size > MAX_HISTORY_VALUES) rawValues.removeFirst()
        previousReportedConfidence = reportedConfidence
        return estimate.copy(
            value = stabilizedValue,
            confidence = reportedConfidence.coerceIn(0.0, 1.0),
        )
    }

    private fun median(values: DoubleArray): Double = RppgSignalResampler.median(values)

    private companion object {
        const val MAX_HISTORY_VALUES = 3
        const val CONFIDENCE_CURRENT_WEIGHT = 0.6
        const val EPSILON = 1e-9
    }
}
