package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgRespirationEstimatorTest {
    @Test
    fun detectsFifteenBreathsPerMinute() {
        val estimate = estimate(sinusoidSamples(durationSeconds = 20.0, frequencyHz = 0.25))

        assertTrue(estimate.available)
        assertEquals(15.0, requireNotNull(estimate.value), 1.0)
        assertEquals(15.0, requireNotNull(estimate.rawValue), 1.0)
    }

    @Test
    fun physiologicalBandEdgesAreMeasuredRatherThanUsedAsFallbacks() {
        val low = estimate(sinusoidSamples(durationSeconds = 20.0, frequencyHz = 0.15))
        val high = estimate(sinusoidSamples(durationSeconds = 20.0, frequencyHz = 0.40))
        val nearLow = estimate(sinusoidSamples(durationSeconds = 50.0, frequencyHz = 0.16))
        val nearHigh = estimate(sinusoidSamples(durationSeconds = 50.0, frequencyHz = 0.38))

        assertTrue(low.toString(), low.available)
        assertTrue(high.toString(), high.available)
        assertTrue(nearLow.toString(), nearLow.available)
        assertTrue(nearHigh.toString(), nearHigh.available)
        assertEquals(9.0, requireNotNull(low.rawValue), 1.0)
        assertEquals(24.0, requireNotNull(high.rawValue), 1.0)
        assertEquals(9.6, requireNotNull(nearLow.rawValue), 0.7)
        assertEquals(22.8, requireNotNull(nearHigh.rawValue), 0.7)
        assertTrue(requireNotNull(nearLow.rawValue) > 9.0)
        assertTrue(requireNotNull(nearHigh.rawValue) < 24.0)
    }

    @Test
    fun rejectsDurationShorterThanTwelveSeconds() {
        val estimate = estimate(sinusoidSamples(durationSeconds = 11.9, frequencyHz = 0.25))

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.InsufficientDuration, estimate.rejectionReason)
    }

    @Test
    fun rejectsFewerThanThreeRespiratoryCycles() {
        val estimate = estimate(sinusoidSamples(durationSeconds = 12.0, frequencyHz = 0.15))

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.InsufficientPhysiologicalCycles, estimate.rejectionReason)
    }

    @Test
    fun rejectsFlatSignalWithoutInventingValue() {
        val estimate = estimate(timedSamples(20.0) { 4.2 })

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.LowSignalEnergy, estimate.rejectionReason)
        assertEquals(null, estimate.value)
    }

    @Test
    fun deterministicWhiteNoiseNeverProducesHighConfidence() {
        val random = Random(71)
        val estimate = estimate(timedSamples(20.0) { random.nextDouble(-1.0, 1.0) })

        assertTrue(!estimate.available || estimate.confidence < 0.7)
    }

    @Test
    fun rejectsSpectrumWhosePeakIsBelowOnePointFiveTimesBandMean() {
        val frequencies = listOf(0.15, 0.20, 0.25, 0.30, 0.35, 0.40)
        val estimate = estimate(
            timedSamples(20.0) { time ->
                frequencies.sumOf { frequency -> sin(2.0 * PI * frequency * time) }
            },
        )

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.WeakRespiratoryPeak, estimate.rejectionReason)
    }

    @Test
    fun weakButPassingPeakCanRemainAvailableWithLowConfidence() {
        val estimate = estimate(
            timedSamples(12.1) { time ->
                sin(2.0 * PI * 0.25 * time) +
                    0.55 * sin(2.0 * PI * 0.1666666667 * time) +
                    0.55 * sin(2.0 * PI * 0.3333333333 * time)
            },
        )

        assertTrue(estimate.toString(), estimate.available)
        assertTrue(estimate.confidence < 0.7)
    }

    @Test
    fun irregularTimestampsAreResampledWithoutChangingRate() {
        var time = 0.0
        val samples = buildList {
            add(TimedRppgSample(0.0, 0.0))
            while (time < 20.0) {
                time += if (size % 3 == 0) 0.029 else 0.035
                add(TimedRppgSample(time, sin(2.0 * PI * 0.25 * time)))
            }
        }
        val estimate = estimate(samples)

        assertTrue(estimate.available)
        assertEquals(15.0, requireNotNull(estimate.rawValue), 1.0)
        assertTrue(requireNotNull(estimate.diagnostics.timeQuality) > 0.7)
    }

    @Test
    fun excessiveGapUsesSharedStageThreeRejection() {
        val samples = buildList {
            repeat(180) { index ->
                val time = index / 30.0
                add(TimedRppgSample(time, sin(2.0 * PI * 0.25 * time)))
            }
            repeat(360) { index ->
                val time = 7.0 + index / 30.0
                add(TimedRppgSample(time, sin(2.0 * PI * 0.25 * time)))
            }
        }
        val estimate = estimate(samples)

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.ExcessiveLocalGap, estimate.rejectionReason)
    }

    @Test
    fun segmentResetPreventsHistoryFromCrossingBoundary() {
        val estimator = RppgRespirationEstimator()
        estimator.beginSegment(1L)
        val first = estimator.estimate(sinusoidSamples(20.0, 0.25), 1L)
        val smoothed = estimator.estimate(sinusoidSamples(20.0, 0.30), 1L)
        estimator.beginSegment(2L)
        val afterReset = estimator.estimate(sinusoidSamples(20.0, 0.30), 2L)

        assertEquals(15.0, requireNotNull(first.value), 1.0)
        assertTrue(requireNotNull(smoothed.value) < requireNotNull(smoothed.rawValue))
        assertEquals(requireNotNull(afterReset.rawValue), requireNotNull(afterReset.value), 1e-9)
    }

    @Test
    fun confidenceImprovesFromTwelveToTwentySecondsForCleanSignal() {
        val twelve = estimate(sinusoidSamples(12.1, 0.25), segmentId = 1L)
        val twenty = estimate(sinusoidSamples(20.0, 0.25), segmentId = 2L)

        assertTrue(twelve.toString(), twelve.available)
        assertTrue(twenty.toString(), twenty.available)
        assertTrue("twelve=$twelve twenty=$twenty", twenty.confidence > twelve.confidence)
    }

    private fun estimate(samples: List<TimedRppgSample>, segmentId: Long = 7L): MetricEstimate {
        val estimator = RppgRespirationEstimator()
        estimator.beginSegment(segmentId)
        return estimator.estimate(samples, segmentId)
    }

    private fun sinusoidSamples(
        durationSeconds: Double,
        frequencyHz: Double,
    ): List<TimedRppgSample> = timedSamples(durationSeconds) { time ->
        sin(2.0 * PI * frequencyHz * time)
    }

    private fun timedSamples(
        durationSeconds: Double,
        sampleRateHz: Double = 30.0,
        value: (Double) -> Double,
    ): List<TimedRppgSample> {
        val count = (durationSeconds * sampleRateHz).toInt() + 1
        return List(count) { index ->
            val time = index / sampleRateHz
            TimedRppgSample(time, value(time))
        }
    }
}
