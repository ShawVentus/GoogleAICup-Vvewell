package com.vvewell.health.core.rppg

import kotlin.math.max

internal object RppgPrerollReadinessConfig {
    const val MIN_CONSECUTIVE_VALID_FRAMES = 8
    const val MIN_WINDOW_SECONDS = 0.8
    const val MIN_SAMPLE_RATE_HZ = 6.0
    const val MAX_LOCAL_GAP_SECONDS = 0.35
    const val MAX_TRACKED_WINDOW_SECONDS = 2.0
    const val SLOW_PREPARATION_SECONDS = 8.0
}

internal data class RppgPrerollReadiness(
    val ready: Boolean,
    val frameCount: Int,
    val durationSeconds: Double,
    val sampleRateHz: Double,
    val maximumGapSeconds: Double,
    val hadTimestampFallback: Boolean,
    val hadStallReset: Boolean,
    val facePresent: Boolean,
    val roiValid: Boolean,
)

/**
 * Pure readiness gate for real-camera pre-roll inference outputs.
 *
 * Invalid observations break continuity. A large gap starts a fresh candidate
 * window at the current frame so a device can recover without a fixed delay.
 */
internal class RppgPrerollReadinessEvaluator {
    private val timestampsSeconds = ArrayDeque<Double>()
    private var lastResult = emptyReadiness()

    fun recordValidInference(
        timestampSeconds: Double,
        timestampFallback: Boolean = false,
        stallReset: Boolean = false,
        facePresent: Boolean = true,
        roiValid: Boolean = true,
    ): RppgPrerollReadiness {
        if (
            !timestampSeconds.isFinite() || timestampFallback || stallReset ||
            !facePresent || !roiValid
        ) {
            timestampsSeconds.clear()
            return update(
                hadTimestampFallback = timestampFallback,
                hadStallReset = stallReset,
                facePresent = facePresent,
                roiValid = roiValid,
            )
        }

        val previous = timestampsSeconds.lastOrNull()
        if (previous != null && timestampSeconds <= previous) {
            timestampsSeconds.clear()
        } else if (
            previous != null &&
            timestampSeconds - previous > RppgPrerollReadinessConfig.MAX_LOCAL_GAP_SECONDS
        ) {
            timestampsSeconds.clear()
        }
        timestampsSeconds.addLast(timestampSeconds)
        while (
            timestampsSeconds.size > 1 &&
            timestampSeconds - timestampsSeconds.first() >
            RppgPrerollReadinessConfig.MAX_TRACKED_WINDOW_SECONDS
        ) {
            timestampsSeconds.removeFirst()
        }
        return update(facePresent = true, roiValid = true)
    }

    fun recordInvalidFace(): RppgPrerollReadiness {
        timestampsSeconds.clear()
        return update(facePresent = false, roiValid = false)
    }

    fun recordInvalidInference(): RppgPrerollReadiness {
        timestampsSeconds.clear()
        return update()
    }

    fun recordStallReset(): RppgPrerollReadiness {
        timestampsSeconds.clear()
        return update(hadStallReset = true)
    }

    fun snapshot(): RppgPrerollReadiness = lastResult

    fun reset() {
        timestampsSeconds.clear()
        lastResult = emptyReadiness()
    }

    private fun update(
        hadTimestampFallback: Boolean = false,
        hadStallReset: Boolean = false,
        facePresent: Boolean = true,
        roiValid: Boolean = true,
    ): RppgPrerollReadiness {
        val duration = if (timestampsSeconds.size >= 2) {
            timestampsSeconds.last() - timestampsSeconds.first()
        } else {
            0.0
        }
        val sampleRate = if (duration > 0.0) {
            (timestampsSeconds.size - 1) / duration
        } else {
            0.0
        }
        var maximumGap = 0.0
        var previous: Double? = null
        timestampsSeconds.forEach { timestamp ->
            previous?.let { maximumGap = max(maximumGap, timestamp - it) }
            previous = timestamp
        }
        val ready = timestampsSeconds.size >=
            RppgPrerollReadinessConfig.MIN_CONSECUTIVE_VALID_FRAMES &&
            duration + TIME_EPSILON_SECONDS >= RppgPrerollReadinessConfig.MIN_WINDOW_SECONDS &&
            sampleRate >= RppgPrerollReadinessConfig.MIN_SAMPLE_RATE_HZ &&
            maximumGap <= RppgPrerollReadinessConfig.MAX_LOCAL_GAP_SECONDS &&
            !hadTimestampFallback && !hadStallReset && facePresent && roiValid
        return RppgPrerollReadiness(
            ready = ready,
            frameCount = timestampsSeconds.size,
            durationSeconds = duration,
            sampleRateHz = sampleRate,
            maximumGapSeconds = maximumGap,
            hadTimestampFallback = hadTimestampFallback,
            hadStallReset = hadStallReset,
            facePresent = facePresent,
            roiValid = roiValid,
        ).also { lastResult = it }
    }

    private fun emptyReadiness() = RppgPrerollReadiness(
        ready = false,
        frameCount = 0,
        durationSeconds = 0.0,
        sampleRateHz = 0.0,
        maximumGapSeconds = 0.0,
        hadTimestampFallback = false,
        hadStallReset = false,
        facePresent = false,
        roiValid = false,
    )

    private companion object {
        const val TIME_EPSILON_SECONDS = 1e-9
    }
}
