package com.vvewell.health.core.rppg

import java.nio.file.Files
import java.time.OffsetDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyntheticVitalsTest {
    @Test
    fun generatedSpO2AlwaysFallsWithinDebugDemoRange() {
        val values = (0..3).map { spo2Draw ->
            requireNotNull(factory(true, spo2Draw, 0).create()).demoSpO2
        }

        assertEquals(listOf(96, 97, 98, 99), values)
        assertTrue(values.all { it in 96..99 })
    }

    @Test
    fun stressThresholdProducesExactlyEightyNormalAndTwentyElevatedOutcomes() {
        val statuses = (0 until 100).map { stressDraw ->
            requireNotNull(factory(true, 0, stressDraw).create()).demoStressStatus
        }

        assertEquals(80, statuses.count { it == SyntheticStressStatus.Normal })
        assertEquals(20, statuses.count { it == SyntheticStressStatus.Elevated })
        assertEquals(setOf(SyntheticStressStatus.Normal, SyntheticStressStatus.Elevated), statuses.toSet())
    }

    @Test
    fun completedStateKeepsOneSyntheticValueForSameSession() {
        val source = SequenceIntSource(2, 79, 3, 99)
        val session = RppgMeasurementSession(SyntheticVitalsFactory(true, source::nextInt))
        beginMeasurement(session)

        val first = session.complete(availableHeartRate(), rejectedRespiration()).syntheticVitals
        val repeated = session.complete(availableHeartRate(), rejectedRespiration()).syntheticVitals

        assertEquals(SyntheticVitals(98, SyntheticStressStatus.Normal), first)
        assertEquals(first, repeated)
        assertEquals(2, source.callCount)
    }

    @Test
    fun newMeasurementRoundGeneratesIndependentSyntheticValue() {
        val source = SequenceIntSource(0, 0, 3, 99)
        val session = RppgMeasurementSession(SyntheticVitalsFactory(true, source::nextInt))
        beginMeasurement(session)
        val first = requireNotNull(
            session.complete(availableHeartRate(), rejectedRespiration()).syntheticVitals,
        )

        beginMeasurement(session)
        val second = requireNotNull(
            session.complete(availableHeartRate(), rejectedRespiration()).syntheticVitals,
        )

        assertEquals(SyntheticVitals(96, SyntheticStressStatus.Normal), first)
        assertEquals(SyntheticVitals(99, SyntheticStressStatus.Elevated), second)
        assertNotEquals(first, second)
        assertEquals(4, source.callCount)
    }

    @Test
    fun measuringStatesNeverGenerateSyntheticVitals() {
        val source = SequenceIntSource(1, 1)
        val session = RppgMeasurementSession(SyntheticVitalsFactory(true, source::nextInt))

        beginMeasurement(session)
        session.onFirstSample()
        val measuring = session.updateEffectiveElapsed(12_000L)

        assertEquals(RppgPhase.Estimating, measuring.phase)
        assertNull(measuring.syntheticVitals)
        assertEquals(0, source.callCount)
    }

    @Test
    fun lowQualityCompletionDoesNotGenerateSyntheticVitals() {
        val source = SequenceIntSource(1, 1)
        val session = RppgMeasurementSession(SyntheticVitalsFactory(true, source::nextInt))
        beginMeasurement(session)

        val completed = session.complete(rejectedHeartRate(), rejectedRespiration())

        assertEquals(RppgPhase.LowQuality, completed.phase)
        assertNull(completed.syntheticVitals)
        assertEquals(0, source.callCount)
    }

    @Test
    fun releasePathReturnsNullWithoutConsumingRandomness() {
        val source = SequenceIntSource(3, 99)
        val session = RppgMeasurementSession(SyntheticVitalsFactory(false, source::nextInt))
        beginMeasurement(session)

        val completed = session.complete(availableHeartRate(), rejectedRespiration())

        assertEquals(RppgPhase.Completed, completed.phase)
        assertNull(completed.syntheticVitals)
        assertEquals(0, source.callCount)
    }

    @Test
    fun syntheticVitalsDoNotEnterSixColumnCsv() {
        val sessionState = RppgMeasurementSession(factory(true, 2, 99)).run {
            beginMeasurement(this)
            complete(availableHeartRate(), rejectedRespiration())
        }
        assertTrue(sessionState.syntheticVitals != null)

        val directory = Files.createTempDirectory("rppg-synthetic-csv-test").toFile()
        val csv = RppgCsvSession(directory, sessionId = "synthetic")
        assertTrue(
            csv.enqueueSnapshot(
                segmentId = 0L,
                scheduledSecond = 10,
                producedAt = OffsetDateTime.parse("2026-08-01T18:30:00+08:00"),
                heartRate = availableHeartRate(),
                respiration = rejectedRespiration(),
            ),
        )
        csv.close("completed")

        assertTrue(csv.awaitClosedForTest())
        val lines = requireNotNull(csv.fileForTest()).readLines(Charsets.UTF_8)
        assertEquals("时间戳,心率,心率置信度,呼吸率,呼吸率置信度,信号质量", lines.first())
        assertEquals(6, lines[1].split(',').size)
        assertFalse(lines.first().contains("血氧"))
        assertFalse(lines.first().contains("压力"))
    }

    private fun beginMeasurement(session: RppgMeasurementSession) {
        session.beginPreview()
        session.onPrerollReady()
        session.requestStart()
        session.markOfficialMeasurementStarted()
    }

    private fun factory(enabled: Boolean, vararg values: Int): SyntheticVitalsFactory {
        val source = SequenceIntSource(*values)
        return SyntheticVitalsFactory(enabled, source::nextInt)
    }

    private fun availableHeartRate() = MetricEstimate.available(
        type = RppgMetricType.HeartRate,
        value = 72.0,
        confidence = 0.8,
        diagnostics = MetricDiagnostics(sampleCount = 300, durationSeconds = 20.0),
    )

    private fun rejectedHeartRate() = MetricEstimate.rejected(
        type = RppgMetricType.HeartRate,
        reason = MetricRejectionReason.InsufficientDuration,
    )

    private fun rejectedRespiration() = MetricEstimate.rejected(
        type = RppgMetricType.RespirationRate,
        reason = MetricRejectionReason.InsufficientDuration,
    )

    private class SequenceIntSource(vararg values: Int) {
        private val sequence = values.toList()
        var callCount = 0
            private set

        fun nextInt(until: Int): Int {
            check(callCount < sequence.size) { "Synthetic random source was called unexpectedly" }
            return sequence[callCount++].also { value ->
                require(value in 0 until until) { "Test value $value is outside 0 until $until" }
            }
        }
    }
}
