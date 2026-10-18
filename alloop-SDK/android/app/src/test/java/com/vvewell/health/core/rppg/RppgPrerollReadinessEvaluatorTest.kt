package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgPrerollReadinessEvaluatorTest {
    @Test
    fun stableRealFrameWindowBecomesReady() {
        val evaluator = RppgPrerollReadinessEvaluator()

        val result = stableWindow(evaluator)

        assertTrue(result.ready)
        assertEquals(9, result.frameCount)
        assertEquals(0.8, result.durationSeconds, 1e-9)
        assertTrue(result.sampleRateHz >= 6.0)
        assertTrue(result.maximumGapSeconds <= 0.35)
    }

    @Test
    fun largeGapBreaksContinuityAndStartsFreshWindow() {
        val evaluator = RppgPrerollReadinessEvaluator()
        stableWindow(evaluator)

        val result = evaluator.recordValidInference(1.2)

        assertFalse(result.ready)
        assertEquals(1, result.frameCount)
    }

    @Test
    fun timestampFallbackCannotCountTowardReadiness() {
        val evaluator = RppgPrerollReadinessEvaluator()
        repeat(8) { index -> evaluator.recordValidInference(index * 0.1) }

        val result = evaluator.recordValidInference(0.8, timestampFallback = true)

        assertFalse(result.ready)
        assertTrue(result.hadTimestampFallback)
        assertEquals(0, result.frameCount)
    }

    @Test
    fun noFaceOrInvalidRoiClearsCandidateWindow() {
        val evaluator = RppgPrerollReadinessEvaluator()
        stableWindow(evaluator)

        val result = evaluator.recordInvalidFace()

        assertFalse(result.ready)
        assertFalse(result.facePresent)
        assertFalse(result.roiValid)
        assertEquals(0, result.frameCount)
    }

    @Test
    fun insufficientRateAndSpanRemainNotReady() {
        val evaluator = RppgPrerollReadinessEvaluator()

        var result = evaluator.recordValidInference(0.0)
        listOf(0.2, 0.4, 0.6, 0.8).forEach { result = evaluator.recordValidInference(it) }

        assertFalse(result.ready)
        assertEquals(5.0, result.sampleRateHz, 1e-9)
        assertEquals(5, result.frameCount)
    }

    @Test
    fun stallResetRequiresAWholeNewStableWindow() {
        val evaluator = RppgPrerollReadinessEvaluator()
        stableWindow(evaluator)

        val stalled = evaluator.recordStallReset()
        val recovered = stableWindow(evaluator, startSeconds = 2.0)

        assertFalse(stalled.ready)
        assertTrue(stalled.hadStallReset)
        assertTrue(recovered.ready)
    }

    private fun stableWindow(
        evaluator: RppgPrerollReadinessEvaluator,
        startSeconds: Double = 0.0,
    ): RppgPrerollReadiness {
        var result = evaluator.recordValidInference(startSeconds)
        for (index in 1..8) {
            result = evaluator.recordValidInference(startSeconds + index * 0.1)
        }
        return result
    }
}
