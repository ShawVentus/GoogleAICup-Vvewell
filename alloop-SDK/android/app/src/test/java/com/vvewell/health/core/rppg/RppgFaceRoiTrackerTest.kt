package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgFaceRoiTrackerTest {
    @Test
    fun clampsBoundingBoxToImageBounds() {
        val clamped = RppgRectF(
            left = -12f,
            top = 8f,
            right = 112f,
            bottom = 92f,
        ).clamp(imageWidth = 100, imageHeight = 80)

        assertEquals(RppgRectF(0f, 8f, 100f, 80f), clamped)
        assertNull(RppgRectF(120f, 0f, 140f, 20f).clamp(100, 80))
    }

    @Test
    fun smoothsSelectedFaceBoundingBox() {
        val tracker = RppgFaceRoiTracker(
            smoothingAlpha = 0.5f,
            minimumFaceSidePixels = 1f,
        )
        tracker.selectAndSmooth(
            candidates = listOf(face(10f, 10f, 50f, 50f, trackingId = 7)),
            imageWidth = 100,
            imageHeight = 100,
        )

        val smoothed = tracker.selectAndSmooth(
            candidates = listOf(face(20f, 20f, 60f, 60f, trackingId = 7)),
            imageWidth = 100,
            imageHeight = 100,
        )

        assertEquals(RppgRectF(15f, 15f, 55f, 55f), smoothed)
    }

    @Test
    fun selectsLargestInitialFaceThenKeepsItsTrackingId() {
        val tracker = RppgFaceRoiTracker(
            smoothingAlpha = 1f,
            minimumFaceSidePixels = 1f,
        )
        val first = tracker.selectAndSmooth(
            candidates = listOf(
                face(10f, 10f, 30f, 30f, trackingId = 1),
                face(40f, 10f, 80f, 60f, trackingId = 2),
            ),
            imageWidth = 100,
            imageHeight = 100,
        )
        assertEquals(RppgRectF(40f, 10f, 80f, 60f), first)

        val next = tracker.selectAndSmooth(
            candidates = listOf(
                face(0f, 0f, 90f, 90f, trackingId = 3),
                face(42f, 12f, 82f, 62f, trackingId = 2),
            ),
            imageWidth = 100,
            imageHeight = 100,
        )
        assertEquals(RppgRectF(42f, 12f, 82f, 62f), next)
    }

    @Test
    fun doesNotJumpToUnrelatedFaceBeforeTrackerReset() {
        val tracker = RppgFaceRoiTracker(
            smoothingAlpha = 1f,
            minimumTrackingIou = 0.15f,
            minimumFaceSidePixels = 1f,
        )
        assertNotNull(
            tracker.selectAndSmooth(
                listOf(face(0f, 0f, 30f, 30f, trackingId = null)),
                imageWidth = 100,
                imageHeight = 100,
            ),
        )

        assertNull(
            tracker.selectAndSmooth(
                listOf(face(70f, 70f, 100f, 100f, trackingId = null)),
                imageWidth = 100,
                imageHeight = 100,
            ),
        )
    }

    @Test
    fun edgeFaceRemainsInsideImage() {
        val tracker = RppgFaceRoiTracker(
            smoothingAlpha = 1f,
            minimumFaceSidePixels = 1f,
        )

        val selected = tracker.selectAndSmooth(
            listOf(face(-20f, -10f, 55f, 60f, trackingId = 1)),
            imageWidth = 40,
            imageHeight = 40,
        )

        assertEquals(RppgRectF(0f, 0f, 40f, 40f), selected)
    }

    @Test
    fun resetsOnlyOnceAfterContinuousFaceLossThreshold() {
        val tracker = RppgFaceLossTracker(resetAfterNanos = 1_000L)

        assertFalse(tracker.onMissingFace(100L))
        assertFalse(tracker.onMissingFace(1_099L))
        assertTrue(tracker.onMissingFace(1_100L))
        assertFalse(tracker.onMissingFace(2_100L))

        assertFalse(tracker.onReliableFace(2_500L))
        assertFalse(tracker.onMissingFace(3_000L))
        assertTrue(tracker.onMissingFace(4_000L))
    }

    @Test
    fun requestsResetWhenFaceReturnsAfterThresholdBetweenFrames() {
        val tracker = RppgFaceLossTracker(resetAfterNanos = 1_000L)

        assertFalse(tracker.onMissingFace(100L))
        assertTrue(tracker.onReliableFace(1_100L))
        assertFalse(tracker.onReliableFace(1_200L))
    }

    private fun face(
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
        trackingId: Int?,
    ) = RppgFaceCandidate(
        bounds = RppgRectF(left, top, right, bottom),
        trackingId = trackingId,
    )
}
