package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgSignalResamplerTest {
    @Test
    fun targetRateUsesMostConservativeRealTimestampRate() {
        var time = 0.0
        val samples = buildList {
            repeat(301) { index ->
                if (index > 0) time += if (index % 5 == 0) 0.05 else 1.0 / 30.0
                add(TimedRppgSample(time, sin(2.0 * PI * 0.25 * time)))
            }
        }

        val outcome = RppgSignalResampler.resample(samples) as RppgResampleOutcome.Success

        val diagnostics = outcome.signal.diagnostics
        assertEquals(
            minOf(
                30.0,
                requireNotNull(diagnostics.medianSampleRateHz),
                requireNotNull(diagnostics.spanSampleRateHz),
            ),
            outcome.signal.sampleRateHz,
            1e-9,
        )
        assertTrue(requireNotNull(diagnostics.timeQuality) in 0.0..1.0)
    }

    @Test
    fun rejectsNonIncreasingTimestampBeforeInterpolation() {
        val outcome = RppgSignalResampler.resample(
            listOf(
                TimedRppgSample(0.0, 0.0),
                TimedRppgSample(0.1, 1.0),
                TimedRppgSample(0.1, 2.0),
            ),
        ) as RppgResampleOutcome.Rejected

        assertEquals(MetricRejectionReason.NonIncreasingTimestamp, outcome.reason)
    }
}
