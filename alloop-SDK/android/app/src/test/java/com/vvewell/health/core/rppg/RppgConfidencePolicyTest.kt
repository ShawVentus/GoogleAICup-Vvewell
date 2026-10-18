package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgConfidencePolicyTest {
    @Test
    fun nonFiniteAvailableInputsBecomeHardRejections() {
        listOf(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY).forEach { confidence ->
            val estimate = MetricEstimate.available(
                type = RppgMetricType.HeartRate,
                value = 72.0,
                confidence = confidence,
                diagnostics = MetricDiagnostics(),
            )

            assertFalse(estimate.available)
            assertEquals(0.0, estimate.confidence, 0.0)
            assertEquals(MetricRejectionReason.NumericalFailure, estimate.rejectionReason)
        }
    }

    @Test
    fun nonFiniteValuesBecomeHardRejections() {
        val valueEstimate = MetricEstimate.available(
            type = RppgMetricType.HeartRate,
            value = Double.POSITIVE_INFINITY,
            rawValue = 72.0,
            confidence = 0.8,
            diagnostics = MetricDiagnostics(),
        )
        val rawValueEstimate = MetricEstimate.available(
            type = RppgMetricType.HeartRate,
            value = 72.0,
            rawValue = Double.NaN,
            confidence = 0.8,
            diagnostics = MetricDiagnostics(),
        )

        listOf(valueEstimate, rawValueEstimate).forEach { estimate ->
            assertFalse(estimate.available)
            assertNull(estimate.value)
            assertEquals(MetricRejectionReason.NumericalFailure, estimate.rejectionReason)
        }
    }

    @Test
    fun finiteConfidenceIsClampedToTheContractRange() {
        assertEquals(
            1.0,
            available(RppgMetricType.HeartRate, 66.0, 1.2).confidence,
            0.0,
        )
        assertEquals(
            0.0,
            available(RppgMetricType.RespirationRate, 22.0, -0.2).confidence,
            0.0,
        )
    }

    @Test
    fun heartRateAndRespirationUseTheSameLabelRule() {
        val lowHeartRate = available(RppgMetricType.HeartRate, 66.0, 0.699)
        val lowRespiration = available(RppgMetricType.RespirationRate, 22.0, 0.699)
        val highHeartRate = available(RppgMetricType.HeartRate, 66.0, 0.7)
        val highRespiration = available(RppgMetricType.RespirationRate, 22.0, 0.7)

        assertEquals(RppgConfidenceLabel.ReferenceOnly, RppgConfidencePolicy.labelFor(lowHeartRate))
        assertEquals(RppgConfidenceLabel.ReferenceOnly, RppgConfidencePolicy.labelFor(lowRespiration))
        assertEquals(RppgConfidenceLabel.HighConfidence, RppgConfidencePolicy.labelFor(highHeartRate))
        assertEquals(RppgConfidenceLabel.HighConfidence, RppgConfidencePolicy.labelFor(highRespiration))
        assertNull(RppgConfidencePolicy.labelFor(rejected(RppgMetricType.HeartRate)))
    }

    @Test
    fun conservativeAggregateUsesMetricConfidenceNotAutocorrelationSqi() {
        val heartRate = available(
            type = RppgMetricType.HeartRate,
            value = 66.0,
            confidence = 0.757,
            diagnostics = MetricDiagnostics(signalQuality = 0.23),
        )
        val respiration = available(RppgMetricType.RespirationRate, 22.0, 0.855)

        assertEquals(
            0.757,
            RppgConfidencePolicy.conservativeAggregateQuality(heartRate, respiration),
            1e-9,
        )
    }

    @Test
    fun aggregateUsesOneAvailableMetricOrZeroWhenNoneAvailable() {
        val heartRate = available(RppgMetricType.HeartRate, 66.0, 0.757)
        val rejectedRespiration = rejected(RppgMetricType.RespirationRate)

        assertEquals(
            0.757,
            RppgConfidencePolicy.conservativeAggregateQuality(heartRate, rejectedRespiration),
            1e-9,
        )
        assertEquals(
            0.0,
            RppgConfidencePolicy.conservativeAggregateQuality(
                rejected(RppgMetricType.HeartRate),
                rejectedRespiration,
            ),
            0.0,
        )
    }

    private fun available(
        type: RppgMetricType,
        value: Double,
        confidence: Double,
        diagnostics: MetricDiagnostics = MetricDiagnostics(),
    ): MetricEstimate = MetricEstimate.available(type, value, confidence = confidence, diagnostics = diagnostics)

    private fun rejected(type: RppgMetricType): MetricEstimate = MetricEstimate.rejected(
        type = type,
        reason = MetricRejectionReason.InsufficientDuration,
    )
}
