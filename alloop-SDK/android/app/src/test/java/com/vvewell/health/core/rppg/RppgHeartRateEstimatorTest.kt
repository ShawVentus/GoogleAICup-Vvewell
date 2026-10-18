package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgHeartRateEstimatorTest {
    @Test
    fun detectsSeventyTwoBpm() {
        val estimate = estimate(samples(20.0) { time -> sin(2.0 * PI * 1.2 * time) })

        assertTrue(estimate.toString(), estimate.available)
        assertEquals(72.0, requireNotNull(estimate.rawValue), 2.0)
    }

    @Test
    fun detectsOneHundredTwentyBpm() {
        val estimate = estimate(samples(20.0) { time -> sin(2.0 * PI * 2.0 * time) })

        assertTrue(estimate.toString(), estimate.available)
        assertEquals(120.0, requireNotNull(estimate.rawValue), 3.0)
    }

    @Test
    fun toleratesTrendDcOffsetAndHarmonic() {
        val estimate = estimate(
            samples(20.0) { time ->
                4.0 + 0.04 * time + sin(2.0 * PI * 1.2 * time) +
                    0.25 * sin(2.0 * PI * 2.4 * time)
            },
        )

        assertTrue(estimate.toString(), estimate.available)
        assertEquals(72.0, requireNotNull(estimate.rawValue), 3.0)
    }

    @Test
    fun whiteNoiseConfidenceIsBelowCleanPeriodicSignal() {
        val clean = estimate(samples(20.0) { time -> sin(2.0 * PI * 1.2 * time) }, 1L)
        val random = Random(91)
        val noise = estimate(samples(20.0) { random.nextDouble(-1.0, 1.0) }, 2L)

        assertTrue(clean.available)
        assertTrue("clean=$clean noise=$noise", noise.confidence < clean.confidence)
    }

    @Test
    fun flatSignalIsUnavailable() {
        val estimate = estimate(samples(20.0) { 3.0 })

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.LowSignalEnergy, estimate.rejectionReason)
        assertNull(estimate.value)
    }

    @Test
    fun durationBelowTenSecondsIsUnavailable() {
        val estimate = estimate(samples(9.9) { time -> sin(2.0 * PI * 1.2 * time) })

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.InsufficientDuration, estimate.rejectionReason)
    }

    @Test
    fun sampleRateBelowSixHertzIsUnavailable() {
        val estimate = estimate(
            samples(20.0, sampleRateHz = 5.0) { time -> sin(2.0 * PI * 1.2 * time) },
        )

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.SampleRateTooLow, estimate.rejectionReason)
    }

    @Test
    fun irregularTimestampsRemainStable() {
        var time = 0.0
        val input = buildList {
            add(TimedRppgSample(0.0, 0.0))
            while (time < 20.0) {
                time += if (size % 3 == 0) 0.029 else 0.035
                add(TimedRppgSample(time, sin(2.0 * PI * 1.2 * time)))
            }
        }

        val estimate = estimate(input)

        assertTrue(estimate.toString(), estimate.available)
        assertEquals(72.0, requireNotNull(estimate.rawValue), 3.0)
    }

    @Test
    fun excessiveGapRetainsSharedRejection() {
        val input = buildList {
            repeat(180) { index ->
                val time = index / 30.0
                add(TimedRppgSample(time, sin(2.0 * PI * 1.2 * time)))
            }
            repeat(360) { index ->
                val time = 7.0 + index / 30.0
                add(TimedRppgSample(time, sin(2.0 * PI * 1.2 * time)))
            }
        }

        val estimate = estimate(input)

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.ExcessiveLocalGap, estimate.rejectionReason)
    }

    @Test
    fun emdFailureDoesNotReturnSeventyFiveOrOldEstimatorFallback() {
        val estimator = RppgHeartRateEstimator(
            emd = RppgEmd(RppgEmdConfig(maximumSiftIterations = 0)),
        )
        estimator.beginSegment(4L)

        val estimate = estimator.estimate(
            samples(20.0) { time -> sin(2.0 * PI * 1.2 * time) },
            4L,
        )

        assertFalse(estimate.available)
        assertEquals(MetricRejectionReason.EmdDidNotConverge, estimate.rejectionReason)
        assertNull(estimate.value)
        assertNull(estimate.rawValue)
    }

    @Test
    fun periodicAutocorrelationSqiExceedsNoise() {
        val estimator = RppgHeartRateEstimator()
        val periodic = DoubleArray(600) { index -> sin(2.0 * PI * 1.2 * index / 30.0) }
        val random = Random(17)
        val noise = DoubleArray(600) { random.nextDouble(-1.0, 1.0) }

        val periodicSqi = estimator.autocorrelationSqi(periodic, 30.0)
        val noiseSqi = estimator.autocorrelationSqi(noise, 30.0)

        assertTrue(periodicSqi.quality > noiseSqi.quality)
        assertEquals(72.0, requireNotNull(periodicSqi.peakBpm), 3.0)
    }

    @Test
    fun segmentResetCompletelyIsolatesHistory() {
        val estimator = RppgHeartRateEstimator()
        estimator.beginSegment(1L)
        val first = estimator.estimate(samples(20.0) { time -> sin(2.0 * PI * 1.2 * time) }, 1L)
        val smoothed = estimator.estimate(samples(20.0) { time -> sin(2.0 * PI * 2.0 * time) }, 1L)
        estimator.beginSegment(2L)
        val reset = estimator.estimate(samples(20.0) { time -> sin(2.0 * PI * 2.0 * time) }, 2L)

        assertTrue(first.available && smoothed.available && reset.available)
        assertTrue(requireNotNull(smoothed.value) < requireNotNull(smoothed.rawValue))
        assertEquals(requireNotNull(reset.rawValue), requireNotNull(reset.value), 1e-9)
    }

    @Test
    fun confidenceImprovesFromTenToTwentySeconds() {
        val ten = estimate(samples(10.1) { time -> sin(2.0 * PI * 1.2 * time) }, 1L)
        val twenty = estimate(samples(20.0) { time -> sin(2.0 * PI * 1.2 * time) }, 2L)

        assertTrue(ten.toString(), ten.available)
        assertTrue(twenty.toString(), twenty.available)
        assertTrue("ten=$ten twenty=$twenty", twenty.confidence > ten.confidence)
    }

    @Test
    fun sixtySecondCumulativeWindowRemainsBounded() {
        val estimate = estimate(samples(60.0) { time -> sin(2.0 * PI * 1.2 * time) })

        assertTrue(estimate.toString(), estimate.available)
        assertEquals(72.0, requireNotNull(estimate.rawValue), 2.0)
        assertTrue(requireNotNull(estimate.diagnostics.analysisDurationMillis) < 5_000.0)
    }

    private fun estimate(input: List<TimedRppgSample>, segmentId: Long = 7L): MetricEstimate {
        val estimator = RppgHeartRateEstimator()
        estimator.beginSegment(segmentId)
        return estimator.estimate(input, segmentId)
    }

    private fun samples(
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
