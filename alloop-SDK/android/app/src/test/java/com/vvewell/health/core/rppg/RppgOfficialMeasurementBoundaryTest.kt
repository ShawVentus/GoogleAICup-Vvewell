package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgOfficialMeasurementBoundaryTest {
    @Test
    fun resetDiscardsPrerollResetsRecurrentStateAndKeepsEngineInstance() {
        val official = RppgBvpTimeline()
        val preroll = RppgBvpTimeline()
        val readiness = RppgPrerollReadinessEvaluator()
        val engine = FakeEngine()
        val boundary = RppgOfficialMeasurementBoundary(
            officialTimeline = official,
            prerollTimeline = preroll,
            readinessEvaluator = readiness,
            signalProcessor = RppgSignalProcessor(),
        )
        append(preroll, 10.0, 100.0, 1.0)
        append(preroll, 10.1, 100.1, 2.0)
        repeat(9) { readiness.recordValidInference(it * 0.1) }
        val sameEngine = engine

        val segmentId = boundary.resetForOfficialMeasurement(engine)

        assertSame(sameEngine, engine)
        assertEquals(1, engine.resetCount)
        assertEquals(0, engine.closeCount)
        assertTrue(preroll.snapshot().isEmpty())
        assertTrue(official.snapshot().isEmpty())
        assertEquals(0, readiness.snapshot().frameCount)
        assertEquals(0L, segmentId)
    }

    @Test
    fun nextOfficialFrameGetsFreshZeroTimestampAndNoAnalysisSchedule() {
        val official = RppgBvpTimeline()
        val preroll = RppgBvpTimeline()
        val readiness = RppgPrerollReadinessEvaluator()
        val boundary = RppgOfficialMeasurementBoundary(
            officialTimeline = official,
            prerollTimeline = preroll,
            readinessEvaluator = readiness,
            signalProcessor = RppgSignalProcessor(),
        )
        append(preroll, 40.0, 400.0, 7.0)
        boundary.resetForOfficialMeasurement(FakeEngine())

        val firstTiming = accept(official, 50.0, 500.0)
        val first = official.append(firstTiming, 8.0)

        assertEquals(0.0, firstTiming.timestampSeconds, 0.0)
        assertEquals(0L, first.elapsedMillis)
        assertEquals(1, first.sampleCount)
        assertTrue(first.analysisSecondsDue.isEmpty())
        assertFalse(first.complete)
    }

    private fun append(
        timeline: RppgBvpTimeline,
        sourceSeconds: Double,
        arrivalSeconds: Double,
        value: Double,
    ) {
        timeline.append(accept(timeline, sourceSeconds, arrivalSeconds), value)
    }

    private fun accept(
        timeline: RppgBvpTimeline,
        sourceSeconds: Double,
        arrivalSeconds: Double,
    ): RppgFrameTiming = (
        timeline.prepareFrame(seconds(sourceSeconds), seconds(arrivalSeconds)) as
            RppgFrameTimingDecision.Accepted
        ).timing

    private fun seconds(value: Double): Long = (value * 1_000_000_000L).toLong()

    private class FakeEngine : RppgInferenceEngine {
        var resetCount = 0
        var closeCount = 0

        override fun processFrame(rgb: FloatArray, frameDeltaSeconds: Float): Float = 0f

        override fun reset() {
            resetCount += 1
        }

        override fun close() {
            closeCount += 1
        }
    }
}
