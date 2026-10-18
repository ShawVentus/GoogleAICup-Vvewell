package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgTimingTest {
    @Test
    fun bvpTimeStartsAtFirstValidInferenceFrame() {
        val timeline = RppgBvpTimeline()

        val first = timeline.accept(5.0, 50.0)
        val firstAppend = timeline.append(first, 1.0)
        val second = timeline.accept(5.5, 50.5)
        timeline.append(second, 2.0)

        assertEquals(0.0, first.timestampSeconds, 0.0)
        assertNull(first.actualDtSeconds)
        assertEquals(RppgTimingConfig.MIN_MODEL_DT_SECONDS, first.modelDtSeconds, 0f)
        assertFalse(first.modelDtWasClamped)
        assertEquals(0L, firstAppend.elapsedMillis)
        assertEquals(0.5, timeline.snapshot().last().timestampSeconds, 1e-9)
    }

    @Test
    fun irregularLowFpsSourceAndArrivalSequenceDoesNotResetSegment() {
        val timeline = RppgBvpTimeline()
        var source = 10.0
        var arrival = 100.0
        timeline.append(timeline.accept(source, arrival), 0.0)

        listOf(0.2, 0.8, 0.35, 0.65, 0.4).forEachIndexed { index, delta ->
            source += delta
            arrival += delta
            val timing = timeline.accept(source, arrival)
            assertFalse(timing.segmentResetRequired)
            assertNull(timing.fallbackReason)
            timeline.append(timing, index.toDouble())
        }

        assertEquals(0L, timeline.currentSegmentId())
        assertEquals(2.4, timeline.currentDurationSeconds(), 1e-9)
    }

    @Test
    fun matchingOnePointTwoSecondGapIsRealCameraGapNotTimestampAnomaly() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(1.0, 20.0), 1.0)

        val gap = timeline.accept(2.2, 21.2)
        timeline.append(gap, 2.0)

        assertEquals(1.2, gap.sourceDtSeconds ?: error("source dt"), 1e-9)
        assertEquals(1.2, gap.arrivalDtSeconds ?: error("arrival dt"), 1e-9)
        assertEquals(1.2, gap.actualDtSeconds ?: error("resolved dt"), 1e-9)
        assertNull(gap.fallbackReason)
        assertFalse(gap.segmentResetRequired)
        assertEquals(0L, gap.segmentId)
    }

    @Test
    fun sourceOnlyEightSecondJumpFallsBackToArrivalWithoutResetOrSecondJump() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(10.0, 100.0), 1.0)

        val fallback = timeline.accept(18.0, 100.3)
        timeline.append(fallback, 2.0)
        val next = timeline.accept(18.3, 100.6)
        timeline.append(next, 3.0)

        assertEquals(RppgTimestampFallbackReason.SourceArrivalMismatch, fallback.fallbackReason)
        assertEquals(0.3, fallback.actualDtSeconds ?: error("resolved dt"), 1e-9)
        assertFalse(fallback.segmentResetRequired)
        assertNull(next.fallbackReason)
        assertEquals(0.6, next.timestampSeconds, 1e-9)
        assertEquals(0L, timeline.currentSegmentId())
    }

    @Test
    fun repeatedAndBackwardSourceUseArrivalWithoutNonIncreasingBvpTime() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(10.0, 100.0), 1.0)

        val repeated = timeline.accept(10.0, 100.3)
        timeline.append(repeated, 2.0)
        val backward = timeline.accept(9.5, 100.6)
        timeline.append(backward, 3.0)

        assertEquals(RppgTimestampFallbackReason.SourceNonIncreasing, repeated.fallbackReason)
        assertEquals(RppgTimestampFallbackReason.SourceNonIncreasing, backward.fallbackReason)
        assertEquals(0.0, timeline.snapshot()[0].timestampSeconds, 1e-9)
        assertEquals(0.3, timeline.snapshot()[1].timestampSeconds, 1e-9)
        assertEquals(0.6, timeline.snapshot()[2].timestampSeconds, 1e-9)
    }

    @Test
    fun bothClocksOverHardStallResetExactlyOnceAndNewSegmentStartsAtZero() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(1.0, 10.0), 1.0)
        timeline.append(timeline.accept(1.4, 10.4), 2.0)

        val stalled = timeline.accept(4.6, 13.6)
        timeline.append(stalled, 3.0)
        val next = timeline.accept(4.9, 13.9)
        timeline.append(next, 4.0)

        assertEquals(RppgTimingResetReason.CameraStall, stalled.resetReason)
        assertTrue(stalled.segmentResetRequired)
        assertEquals(0.0, stalled.timestampSeconds, 0.0)
        assertFalse(next.segmentResetRequired)
        assertEquals(1L, timeline.currentSegmentId())
        assertEquals(0.0, timeline.snapshot()[0].timestampSeconds, 1e-9)
        assertEquals(0.3, timeline.snapshot()[1].timestampSeconds, 1e-9)
    }

    @Test
    fun sustainedFaceLossResetPreventsDuplicateCameraStallResetOnRecovery() {
        val timeline = RppgBvpTimeline()
        val faceLoss = RppgFaceLossTracker(resetAfterNanos = 1_000L)
        timeline.append(timeline.accept(1.0, 10.0), 1.0)
        timeline.append(timeline.accept(1.5, 10.5), 2.0)

        assertFalse(faceLoss.onMissingFace(2_000L))
        assertTrue(faceLoss.onMissingFace(3_000L))
        timeline.resetSegment()
        val recovered = timeline.accept(8.0, 17.0)
        timeline.append(recovered, 3.0)

        assertFalse(recovered.segmentResetRequired)
        assertEquals(1L, timeline.currentSegmentId())
        assertEquals(0.0, timeline.snapshot().single().timestampSeconds, 0.0)
    }

    @Test
    fun dtClampDoesNotChangeSegmentId() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(1.0, 10.0), 1.0)

        val slowFrame = timeline.accept(1.7, 10.7)
        timeline.append(slowFrame, 2.0)

        assertTrue(slowFrame.modelDtWasClamped)
        assertEquals(RppgTimingConfig.MAX_MODEL_DT_SECONDS, slowFrame.modelDtSeconds, 0f)
        assertEquals(0L, timeline.currentSegmentId())
    }

    @Test
    fun simulatorStyleTwoToFourFpsSequenceCanReachFirstAnalysisWindow() {
        val timeline = RppgBvpTimeline()
        val due = mutableListOf<Int>()
        var source = 100.0
        var arrival = 1_000.0
        var index = 0
        due += timeline.append(timeline.accept(source, arrival), index++.toDouble()).analysisSecondsDue

        val deltas = listOf(0.25, 0.5, 0.33, 1.2, 0.4, 0.28, 0.75)
        while (timeline.currentDurationSeconds() < 10.0) {
            val delta = deltas[(index - 1) % deltas.size]
            source += delta
            arrival += delta
            val timing = timeline.accept(source, arrival)
            assertFalse(timing.segmentResetRequired)
            due += timeline.append(timing, index++.toDouble()).analysisSecondsDue
        }

        assertTrue(10 in due)
        assertEquals(0L, timeline.currentSegmentId())
    }

    @Test
    fun schedulesEachCumulativeAnalysisWindowExactlyOnce() {
        val timeline = RppgBvpTimeline()
        val due = mutableListOf<Int>()

        for (second in 0..20) {
            val timing = timeline.accept(100.0 + second, 1_000.0 + second)
            due += timeline.append(timing, second.toDouble()).analysisSecondsDue
        }

        assertEquals(listOf(10, 12, 14, 16, 18, 20), due)
    }

    @Test
    fun rejectsFrameOnlyWhenNeitherClockCanAdvance() {
        val timeline = RppgBvpTimeline()
        timeline.append(timeline.accept(2.0, 20.0), 1.0)

        val rejected = timeline.prepareFrame(
            sourceTimestampNanos = seconds(2.0),
            arrivalTimestampNanos = seconds(20.0),
        )

        assertEquals(
            RppgTimestampRejectionReason.NoUsableClock,
            (rejected as RppgFrameTimingDecision.Rejected).reason,
        )
    }

    @Test
    fun completionUsesTwentySecondsOfResolvedBvpNotAbsoluteCameraTime() {
        val timeline = RppgBvpTimeline()
        var lastResult: RppgBvpAppendResult? = null

        for (halfSecond in 0..39) {
            val offset = halfSecond * 0.5
            lastResult = timeline.append(
                timeline.accept(500.0 + offset, 5_000.0 + offset),
                halfSecond.toDouble(),
            )
        }
        assertFalse(requireNotNull(lastResult).complete)

        val twentySeconds = timeline.append(
            timeline.accept(520.0, 5_020.0),
            40.0,
        )
        assertTrue(twentySeconds.complete)
        assertEquals(20_000L, twentySeconds.elapsedMillis)
    }

    private fun RppgBvpTimeline.accept(
        sourceSeconds: Double,
        arrivalSeconds: Double,
    ): RppgFrameTiming = (
        prepareFrame(
            sourceTimestampNanos = seconds(sourceSeconds),
            arrivalTimestampNanos = seconds(arrivalSeconds),
        ) as RppgFrameTimingDecision.Accepted
        ).timing

    private fun seconds(value: Double): Long = (value * 1_000_000_000L).toLong()
}
