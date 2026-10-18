package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgMeasurementSessionTest {
    @Test
    fun preparingWithoutClickBecomesReadyButDoesNotMeasure() {
        val session = RppgMeasurementSession()
        session.beginPreview()

        val transition = session.onPrerollReady()

        assertEquals(RppgPhase.PreviewReady, transition.state.phase)
        assertFalse(transition.beginOfficialMeasurement)
        assertFalse(transition.state.measuring)
    }

    @Test
    fun earlyClickWaitsThenAutomaticallyBeginsExactlyOnce() {
        val session = RppgMeasurementSession()
        session.beginPreview()

        val pending = session.requestStart()
        val ready = session.onPrerollReady()
        val measuring = session.markOfficialMeasurementStarted()
        val duplicateReady = session.onPrerollReady()

        assertEquals(RppgPhase.StartPending, pending.state.phase)
        assertFalse(pending.beginOfficialMeasurement)
        assertEquals(RppgPhase.StartPending, ready.state.phase)
        assertTrue(ready.beginOfficialMeasurement)
        assertEquals(RppgPhase.Aligning, measuring.phase)
        assertFalse(duplicateReady.beginOfficialMeasurement)
    }

    @Test
    fun clickWhileReadyBeginsImmediately() {
        val session = RppgMeasurementSession()
        session.beginPreview()
        session.onPrerollReady()

        val transition = session.requestStart()
        val measuring = session.markOfficialMeasurementStarted()

        assertEquals(RppgPhase.StartPending, transition.state.phase)
        assertTrue(transition.beginOfficialMeasurement)
        assertEquals(RppgPhase.Aligning, measuring.phase)
        assertTrue(measuring.measuring)
    }

    @Test
    fun repeatedClickCannotBeginTwice() {
        val session = RppgMeasurementSession()
        session.beginPreview()
        session.onPrerollReady()

        val first = session.requestStart()
        val second = session.requestStart()
        val measuring = session.markOfficialMeasurementStarted()

        assertTrue(first.beginOfficialMeasurement)
        assertFalse(second.beginOfficialMeasurement)
        assertEquals(RppgPhase.StartPending, second.state.phase)
        assertEquals(RppgPhase.Aligning, measuring.phase)
    }

    @Test
    fun revokedReadinessKeepsUserIntentPending() {
        val session = RppgMeasurementSession()
        session.beginPreview()
        session.onPrerollReady()
        session.requestStart()

        val pending = session.deferOfficialStartUntilReady()
        val recovered = session.onPrerollReady()
        val measuring = session.markOfficialMeasurementStarted()

        assertEquals(RppgPhase.StartPending, pending.phase)
        assertEquals(RppgPhase.StartPending, recovered.state.phase)
        assertTrue(recovered.beginOfficialMeasurement)
        assertEquals(RppgPhase.Aligning, measuring.phase)
    }

    @Test
    fun newRoundClearsPriorResultsAndElapsedTime() {
        val session = RppgMeasurementSession()
        val heartRate = availableMetric(RppgMetricType.HeartRate, 72.0, 0.8)
        val respiration = availableMetric(RppgMetricType.RespirationRate, 16.0, 0.7)
        beginMeasurement(session)
        session.complete(heartRate, respiration)

        val reset = session.beginPreview()

        assertEquals(RppgPhase.PreviewPreparing, reset.phase)
        assertEquals(0L, reset.elapsedMillis)
        assertNull(reset.result)
        assertNull(reset.respiration)
        assertTrue(reset.running)
    }

    @Test
    fun transitionsFromCollectingToEstimatingAtTenSeconds() {
        val session = RppgMeasurementSession()
        beginMeasurement(session)
        session.onFirstSample()

        assertEquals(RppgPhase.Collecting, session.updateEffectiveElapsed(9_999L).phase)
        assertEquals(RppgPhase.Estimating, session.updateEffectiveElapsed(10_000L).phase)
    }

    @Test
    fun terminalStatesAreNotRunning() {
        val session = RppgMeasurementSession()
        beginMeasurement(session)

        val lowQuality = session.complete(
            rejectedMetric(RppgMetricType.HeartRate),
            rejectedMetric(RppgMetricType.RespirationRate),
        )

        assertEquals(RppgPhase.LowQuality, lowQuality.phase)
        assertFalse(lowQuality.running)
        assertEquals(RppgMeasurementState.MEASUREMENT_MILLIS, lowQuality.elapsedMillis)
    }

    @Test
    fun continuousSegmentRestartClearsElapsedTimeAndPreliminaryResults() {
        val session = RppgMeasurementSession()
        val heartRate = availableMetric(RppgMetricType.HeartRate, 72.0, 0.8)
        beginMeasurement(session)
        session.onFirstSample()
        session.updateEffectiveElapsed(12_000L)
        session.updateEstimate(heartRate, rejectedMetric(RppgMetricType.RespirationRate))

        val restarted = session.restartContinuousSegment()

        assertEquals(RppgPhase.Aligning, restarted.phase)
        assertEquals(0L, restarted.elapsedMillis)
        assertNull(restarted.result)
        assertNull(restarted.respiration)
    }

    private fun beginMeasurement(session: RppgMeasurementSession) {
        session.beginPreview()
        session.onPrerollReady()
        session.requestStart()
        session.markOfficialMeasurementStarted()
    }

    private fun availableMetric(
        type: RppgMetricType,
        value: Double,
        confidence: Double,
    ) = MetricEstimate.available(
        type = type,
        value = value,
        confidence = confidence,
        diagnostics = MetricDiagnostics(sampleCount = 300, durationSeconds = 20.0),
    )

    private fun rejectedMetric(type: RppgMetricType) = MetricEstimate.rejected(
        type = type,
        reason = MetricRejectionReason.InsufficientDuration,
    )
}
