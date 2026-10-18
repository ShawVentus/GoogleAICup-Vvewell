package com.vvewell.health.core.rppg

import kotlin.math.max
import kotlin.math.min

/**
 * Pure face-ROI policy shared by the CameraX pipeline and JVM tests.
 *
 * ML Kit's full-face bounding box is used directly; the UI guide oval is
 * intentionally not part of this geometry.
 */
internal object RppgFaceRoiConfig {
    const val BOUNDING_BOX_SMOOTHING_ALPHA = 0.35f
    const val MIN_TRACKING_IOU = 0.15f
    const val MIN_FACE_SIDE_PIXELS = 24f
    const val MIN_DETECTOR_FACE_SIZE = 0.15f
    const val FACE_LOSS_RESET_NANOS = 1_000_000_000L
    const val DIAGNOSTIC_LOG_INTERVAL_NANOS = 1_000_000_000L
}

internal data class RppgRectF(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
) {
    val width: Float get() = right - left
    val height: Float get() = bottom - top
    val area: Float get() = max(0f, width) * max(0f, height)

    fun clamp(imageWidth: Int, imageHeight: Int): RppgRectF? {
        require(imageWidth > 0 && imageHeight > 0) { "rPPG image dimensions must be positive" }
        val clamped = RppgRectF(
            left = left.coerceIn(0f, imageWidth.toFloat()),
            top = top.coerceIn(0f, imageHeight.toFloat()),
            right = right.coerceIn(0f, imageWidth.toFloat()),
            bottom = bottom.coerceIn(0f, imageHeight.toFloat()),
        )
        return clamped.takeIf { it.width > 0f && it.height > 0f }
    }

    fun intersectionOverUnion(other: RppgRectF): Float {
        val intersectionWidth = max(0f, min(right, other.right) - max(left, other.left))
        val intersectionHeight = max(0f, min(bottom, other.bottom) - max(top, other.top))
        val intersection = intersectionWidth * intersectionHeight
        val union = area + other.area - intersection
        return if (union > 0f) intersection / union else 0f
    }

    fun interpolate(target: RppgRectF, alpha: Float): RppgRectF {
        require(alpha in 0f..1f) { "Smoothing alpha must be within [0, 1]" }
        return RppgRectF(
            left = left + (target.left - left) * alpha,
            top = top + (target.top - top) * alpha,
            right = right + (target.right - right) * alpha,
            bottom = bottom + (target.bottom - bottom) * alpha,
        )
    }
}

internal data class RppgFaceCandidate(
    val bounds: RppgRectF,
    val trackingId: Int?,
)

internal class RppgFaceRoiTracker(
    private val smoothingAlpha: Float = RppgFaceRoiConfig.BOUNDING_BOX_SMOOTHING_ALPHA,
    private val minimumTrackingIou: Float = RppgFaceRoiConfig.MIN_TRACKING_IOU,
    private val minimumFaceSidePixels: Float = RppgFaceRoiConfig.MIN_FACE_SIDE_PIXELS,
) {
    private var selectedTrackingId: Int? = null
    private var smoothedBounds: RppgRectF? = null

    fun selectAndSmooth(
        candidates: List<RppgFaceCandidate>,
        imageWidth: Int,
        imageHeight: Int,
    ): RppgRectF? {
        val reliableCandidates = candidates.mapNotNull { candidate ->
            candidate.bounds.clamp(imageWidth, imageHeight)
                ?.takeIf {
                    it.width >= minimumFaceSidePixels && it.height >= minimumFaceSidePixels
                }
                ?.let { candidate.copy(bounds = it) }
        }
        if (reliableCandidates.isEmpty()) return null

        val previousBounds = smoothedBounds
        val selected = selectPrimaryFace(reliableCandidates, selectedTrackingId, previousBounds)
            ?: return null
        selectedTrackingId = selected.trackingId
        smoothedBounds = if (previousBounds == null) {
            selected.bounds
        } else {
            previousBounds.interpolate(selected.bounds, smoothingAlpha)
        }.clamp(imageWidth, imageHeight)
        return smoothedBounds
    }

    fun reset() {
        selectedTrackingId = null
        smoothedBounds = null
    }

    private fun selectPrimaryFace(
        candidates: List<RppgFaceCandidate>,
        previousTrackingId: Int?,
        previousBounds: RppgRectF?,
    ): RppgFaceCandidate? {
        if (previousTrackingId != null) {
            candidates.firstOrNull { it.trackingId == previousTrackingId }?.let { return it }
        }
        if (previousBounds != null) {
            val bestOverlap = candidates.maxByOrNull {
                previousBounds.intersectionOverUnion(it.bounds)
            } ?: return null
            return bestOverlap.takeIf {
                previousBounds.intersectionOverUnion(it.bounds) >= minimumTrackingIou
            }
        }
        return candidates.maxByOrNull { it.bounds.area }
    }
}

internal class RppgFaceLossTracker(
    private val resetAfterNanos: Long = RppgFaceRoiConfig.FACE_LOSS_RESET_NANOS,
) {
    private var missingSinceNanos: Long? = null
    private var resetIssued = false

    fun onReliableFace(nowNanos: Long): Boolean {
        val shouldReset = missingSinceNanos?.let { missingSince ->
            !resetIssued && nowNanos - missingSince >= resetAfterNanos
        } ?: false
        missingSinceNanos = null
        resetIssued = false
        return shouldReset
    }

    fun onMissingFace(nowNanos: Long): Boolean {
        val missingSince = missingSinceNanos
        if (missingSince == null) {
            missingSinceNanos = nowNanos
            return false
        }
        if (resetIssued || nowNanos - missingSince < resetAfterNanos) return false
        resetIssued = true
        return true
    }

    fun reset() {
        missingSinceNanos = null
        resetIssued = false
    }
}
