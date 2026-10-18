package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgSignalProcessorTest {
    @Test
    fun detectsSeventyTwoBpmSignal() {
        val sampleRate = 30.0
        val signal = List(900) { index ->
            val time = index / sampleRate
            sin(2.0 * PI * 1.2 * time) + 0.15 * sin(2.0 * PI * 2.4 * time)
        }

        val result = RppgSignalProcessor().analyze(signal, sampleRate)
        assertNotNull(result)
        val measured = requireNotNull(result)

        assertEquals(72.0, measured.heartRateBpm, 1.0)
        assertTrue(measured.signalQuality > 0.75)
    }

    @Test
    fun rejectsTooShortSignal() {
        val result = RppgSignalProcessor().analyze(List(30) { 0.0 }, 30.0)
        assertEquals(null, result)
    }

    @Test
    fun usesIrregularSampleTimestampsForHeartRate() {
        var time = 0.0
        val samples = List(600) { index ->
            time += if (index % 3 == 0) 0.029 else 0.035
            TimedRppgSample(time, sin(2.0 * PI * 1.2 * time))
        }

        val result = RppgSignalProcessor().analyzeTimed(samples)

        assertNotNull(result)
        assertEquals(72.0, requireNotNull(result).heartRateBpm, 2.0)
    }

    @Test
    fun detectsSyntheticRespirationFromTimedBvpModulation() {
        val sampleRate = 30.0
        val samples = List(900) { index ->
            val time = index / sampleRate
            TimedRppgSample(
                timestampSeconds = time,
                value = sin(2.0 * PI * 0.3 * time) +
                    0.12 * sin(2.0 * PI * 1.2 * time),
            )
        }

        val result = RppgSignalProcessor().analyzeRespirationTimed(samples)

        assertNotNull(result)
        assertEquals(18.0, requireNotNull(result).breathsPerMinute, 1.0)
        assertTrue(result.signalQuality >= 0.4)
    }

    @Test
    fun respirationReturnsNullWhenWindowIsTooShort() {
        val sampleRate = 30.0
        val samples = List(270) { index ->
            val time = index / sampleRate
            TimedRppgSample(time, sin(2.0 * PI * 0.25 * time))
        }

        assertNull(RppgSignalProcessor().analyzeRespirationTimed(samples))
    }

    @Test
    fun rejectsNonIncreasingTimestampsInsteadOfSortingOrDeduplicating() {
        val samples = listOf(
            TimedRppgSample(0.0, 0.0),
            TimedRppgSample(0.1, 1.0),
            TimedRppgSample(0.1, 2.0),
            TimedRppgSample(0.2, 3.0),
        )

        val attempt = RppgSignalProcessor().analyzeTimedWithDiagnostics(samples)

        assertNull(attempt.result)
        assertEquals(RppgAnalysisRejectionReason.NonIncreasingTimestamp, attempt.rejectionReason)
    }

    @Test
    fun rejectsExcessiveLocalGapRatherThanInterpolatingAcrossIt() {
        val samples = buildList {
            repeat(100) { index -> add(TimedRppgSample(index / 30.0, index.toDouble())) }
            add(TimedRppgSample(5.0, 100.0))
            repeat(100) { index -> add(TimedRppgSample(5.0 + (index + 1) / 30.0, index.toDouble())) }
        }

        val attempt = RppgSignalProcessor().analyzeTimedWithDiagnostics(samples)

        assertNull(attempt.result)
        assertEquals(RppgAnalysisRejectionReason.ExcessiveLocalGap, attempt.rejectionReason)
        assertTrue(requireNotNull(attempt.maximumGapSeconds) > 0.9)
    }

    @Test
    fun estimatesDifferentRatesForSameSampleCountAcrossDifferentDurations() {
        val fast = List(301) { index ->
            val time = index / 30.0
            TimedRppgSample(time, sin(2.0 * PI * 1.2 * time))
        }
        val slow = List(301) { index ->
            val time = index / 15.0
            TimedRppgSample(time, sin(2.0 * PI * 1.2 * time))
        }

        val fastAttempt = RppgSignalProcessor().analyzeTimedWithDiagnostics(fast)
        val slowAttempt = RppgSignalProcessor().analyzeTimedWithDiagnostics(slow)

        assertEquals(30.0, requireNotNull(fastAttempt.effectiveSampleRateHz), 1e-9)
        assertEquals(15.0, requireNotNull(slowAttempt.effectiveSampleRateHz), 1e-9)
    }
}
