package com.vvewell.health.core.rppg

internal object RppgTimingConfig {
    const val FIRST_ANALYSIS_SECONDS = 10
    const val ANALYSIS_INTERVAL_SECONDS = 2
    const val DEFAULT_DURATION_SECONDS = 20
    const val MIN_MODEL_DT_SECONDS = 1f / 120f
    const val MAX_MODEL_DT_SECONDS = 0.2f
    const val SOURCE_ARRIVAL_MISMATCH_TOLERANCE_SECONDS = 0.5
    const val SOURCE_ARRIVAL_MISMATCH_RELATIVE_TOLERANCE = 0.5
    const val HARD_CAMERA_STALL_SECONDS = 3.0
    val FACE_LOSS_RESET_SECONDS: Double
        get() = RppgFaceRoiConfig.FACE_LOSS_RESET_NANOS / NANOS_PER_SECOND
    const val TIMESTAMP_LOG_INTERVAL_NANOS = 1_000_000_000L

    val ANALYSIS_SECONDS: List<Int> =
        (FIRST_ANALYSIS_SECONDS..DEFAULT_DURATION_SECONDS step ANALYSIS_INTERVAL_SECONDS).toList()

    private const val NANOS_PER_SECOND = 1_000_000_000.0
}

internal enum class RppgTimestampRejectionReason {
    NoUsableClock,
}

internal enum class RppgTimestampFallbackReason {
    SourceUnavailable,
    SourceAnchorUnavailable,
    SourceNonIncreasing,
    SourceArrivalMismatch,
}

internal enum class RppgTimingResetReason {
    CameraStall,
}

internal data class RppgFrameTiming(
    val segmentId: Long,
    val sourceTimestampNanos: Long,
    val arrivalTimestampNanos: Long,
    val timestampSeconds: Double,
    val sourceDtSeconds: Double?,
    val arrivalDtSeconds: Double?,
    val actualDtSeconds: Double?,
    val modelDtSeconds: Float,
    val modelDtWasClamped: Boolean,
    val fallbackReason: RppgTimestampFallbackReason?,
    val resetReason: RppgTimingResetReason?,
    val segmentResetRequired: Boolean = resetReason != null,
)

internal sealed interface RppgFrameTimingDecision {
    data class Accepted(val timing: RppgFrameTiming) : RppgFrameTimingDecision
    data class Rejected(
        val reason: RppgTimestampRejectionReason,
        val sourceTimestampNanos: Long,
        val arrivalTimestampNanos: Long,
        val sourceDtSeconds: Double?,
        val arrivalDtSeconds: Double?,
    ) : RppgFrameTimingDecision
}

internal data class RppgBvpAppendResult(
    val segmentId: Long,
    val elapsedMillis: Long,
    val sampleCount: Int,
    val analysisSecondsDue: List<Int>,
    val complete: Boolean,
)

internal data class RppgSegmentResetSummary(
    val segmentId: Long,
    val discardedSampleCount: Int,
    val discardedDurationSeconds: Double,
)

/**
 * Owns the one continuous BVP segment that is eligible for HR/RR analysis.
 * CameraX source time remains primary; host arrival time validates it and is
 * used only as a fallback. The accumulated resolved delta is the sole BVP time.
 */
internal class RppgBvpTimeline {
    private var segmentId = 0L
    private var lastSourceTimestampNanos: Long? = null
    private var lastArrivalTimestampNanos: Long? = null
    private var resolvedElapsedSeconds = 0.0
    private var hasAcceptedFrame = false
    private var nextAnalysisIndex = 0
    private val samples = mutableListOf<TimedRppgSample>()

    @Synchronized
    fun resetMeasurement() {
        segmentId = 0L
        clearCurrentSegment()
    }

    @Synchronized
    fun resetSegment(): RppgSegmentResetSummary {
        val summary = currentResetSummary()
        segmentId += 1
        clearCurrentSegment()
        return summary
    }

    @Synchronized
    fun prepareFrame(
        sourceTimestampNanos: Long,
        arrivalTimestampNanos: Long,
    ): RppgFrameTimingDecision {
        val sourceDt = deltaSeconds(sourceTimestampNanos, lastSourceTimestampNanos)
        val arrivalDt = deltaSeconds(arrivalTimestampNanos, lastArrivalTimestampNanos)
        if (!hasAcceptedFrame) {
            if (sourceTimestampNanos <= 0L && arrivalTimestampNanos <= 0L) {
                return RppgFrameTimingDecision.Rejected(
                    reason = RppgTimestampRejectionReason.NoUsableClock,
                    sourceTimestampNanos = sourceTimestampNanos,
                    arrivalTimestampNanos = arrivalTimestampNanos,
                    sourceDtSeconds = null,
                    arrivalDtSeconds = null,
                )
            }
            anchorClocks(sourceTimestampNanos, arrivalTimestampNanos)
            hasAcceptedFrame = true
            return acceptedFirstFrame(
                sourceTimestampNanos = sourceTimestampNanos,
                arrivalTimestampNanos = arrivalTimestampNanos,
                fallbackReason = if (sourceTimestampNanos > 0L) {
                    null
                } else {
                    RppgTimestampFallbackReason.SourceUnavailable
                },
            )
        }

        val validSourceDt = sourceDt?.takeIf { it > 0.0 }
        val validArrivalDt = arrivalDt?.takeIf { it > 0.0 }
        if (validSourceDt == null && validArrivalDt == null) {
            anchorClocks(sourceTimestampNanos, arrivalTimestampNanos)
            return RppgFrameTimingDecision.Rejected(
                reason = RppgTimestampRejectionReason.NoUsableClock,
                sourceTimestampNanos = sourceTimestampNanos,
                arrivalTimestampNanos = arrivalTimestampNanos,
                sourceDtSeconds = sourceDt,
                arrivalDtSeconds = arrivalDt,
            )
        }

        val cameraStall = validSourceDt != null && validArrivalDt != null &&
            validSourceDt >= RppgTimingConfig.HARD_CAMERA_STALL_SECONDS &&
            validArrivalDt >= RppgTimingConfig.HARD_CAMERA_STALL_SECONDS
        if (cameraStall) {
            segmentId += 1
            clearCurrentSegment()
            anchorClocks(sourceTimestampNanos, arrivalTimestampNanos)
            hasAcceptedFrame = true
            return acceptedFirstFrame(
                sourceTimestampNanos = sourceTimestampNanos,
                arrivalTimestampNanos = arrivalTimestampNanos,
                sourceDtSeconds = sourceDt,
                arrivalDtSeconds = arrivalDt,
                resetReason = RppgTimingResetReason.CameraStall,
            )
        }

        val fallbackReason = fallbackReason(
            sourceTimestampNanos = sourceTimestampNanos,
            sourceDtSeconds = sourceDt,
            validSourceDtSeconds = validSourceDt,
            validArrivalDtSeconds = validArrivalDt,
        )
        val resolvedDt = if (fallbackReason == null) {
            checkNotNull(validSourceDt)
        } else {
            validArrivalDt ?: return RppgFrameTimingDecision.Rejected(
                reason = RppgTimestampRejectionReason.NoUsableClock,
                sourceTimestampNanos = sourceTimestampNanos,
                arrivalTimestampNanos = arrivalTimestampNanos,
                sourceDtSeconds = sourceDt,
                arrivalDtSeconds = arrivalDt,
            )
        }
        resolvedElapsedSeconds += resolvedDt
        anchorClocks(sourceTimestampNanos, arrivalTimestampNanos)
        val modelDt = resolvedDt
            .toFloat()
            .coerceIn(
                RppgTimingConfig.MIN_MODEL_DT_SECONDS,
                RppgTimingConfig.MAX_MODEL_DT_SECONDS,
            )

        return RppgFrameTimingDecision.Accepted(
            RppgFrameTiming(
                segmentId = segmentId,
                sourceTimestampNanos = sourceTimestampNanos,
                arrivalTimestampNanos = arrivalTimestampNanos,
                timestampSeconds = resolvedElapsedSeconds,
                sourceDtSeconds = sourceDt,
                arrivalDtSeconds = arrivalDt,
                actualDtSeconds = resolvedDt,
                modelDtSeconds = modelDt,
                modelDtWasClamped = resolvedDt < RppgTimingConfig.MIN_MODEL_DT_SECONDS.toDouble() ||
                    resolvedDt > RppgTimingConfig.MAX_MODEL_DT_SECONDS.toDouble(),
                fallbackReason = fallbackReason,
                resetReason = null,
            ),
        )
    }

    private fun acceptedFirstFrame(
        sourceTimestampNanos: Long,
        arrivalTimestampNanos: Long,
        sourceDtSeconds: Double? = null,
        arrivalDtSeconds: Double? = null,
        fallbackReason: RppgTimestampFallbackReason? = null,
        resetReason: RppgTimingResetReason? = null,
    ) = RppgFrameTimingDecision.Accepted(
        RppgFrameTiming(
            segmentId = segmentId,
            sourceTimestampNanos = sourceTimestampNanos,
            arrivalTimestampNanos = arrivalTimestampNanos,
            timestampSeconds = 0.0,
            sourceDtSeconds = sourceDtSeconds,
            arrivalDtSeconds = arrivalDtSeconds,
            actualDtSeconds = null,
            modelDtSeconds = RppgTimingConfig.MIN_MODEL_DT_SECONDS,
            modelDtWasClamped = false,
            fallbackReason = fallbackReason,
            resetReason = resetReason,
        ),
    )

    /**
     * Source/arrival differences below 0.5 s + 50% of arrivalDt are treated as
     * normal clock jitter. This is independent of FPS and tolerates irregular
     * 0.2–1.5 s delivery while rejecting multi-second source-only jumps.
     */
    private fun fallbackReason(
        sourceTimestampNanos: Long,
        sourceDtSeconds: Double?,
        validSourceDtSeconds: Double?,
        validArrivalDtSeconds: Double?,
    ): RppgTimestampFallbackReason? {
        if (sourceTimestampNanos <= 0L) return RppgTimestampFallbackReason.SourceUnavailable
        if (lastSourceTimestampNanos == null) return RppgTimestampFallbackReason.SourceAnchorUnavailable
        if (validSourceDtSeconds == null) return RppgTimestampFallbackReason.SourceNonIncreasing
        if (validArrivalDtSeconds == null) return null
        val allowedDifference = RppgTimingConfig.SOURCE_ARRIVAL_MISMATCH_TOLERANCE_SECONDS +
            validArrivalDtSeconds * RppgTimingConfig.SOURCE_ARRIVAL_MISMATCH_RELATIVE_TOLERANCE
        return if (kotlin.math.abs(checkNotNull(sourceDtSeconds) - validArrivalDtSeconds) > allowedDifference) {
            RppgTimestampFallbackReason.SourceArrivalMismatch
        } else {
            null
        }
    }

    private fun deltaSeconds(current: Long, previous: Long?): Double? =
        if (current > 0L && previous != null) {
            (current.toDouble() - previous.toDouble()) / NANOS_PER_SECOND
        } else {
            null
        }

    private fun anchorClocks(sourceTimestampNanos: Long, arrivalTimestampNanos: Long) {
        if (sourceTimestampNanos > 0L) lastSourceTimestampNanos = sourceTimestampNanos
        if (arrivalTimestampNanos > 0L) lastArrivalTimestampNanos = arrivalTimestampNanos
    }

    @Synchronized
    fun append(timing: RppgFrameTiming, value: Double): RppgBvpAppendResult {
        require(timing.segmentId == segmentId) { "Cannot append BVP to a stale continuous segment" }
        require(value.isFinite()) { "BVP sample must be finite" }
        require(samples.isEmpty() || timing.timestampSeconds > samples.last().timestampSeconds) {
            "BVP timestamps must be strictly increasing"
        }
        samples += TimedRppgSample(timing.timestampSeconds, value)

        val due = mutableListOf<Int>()
        while (
            nextAnalysisIndex < RppgTimingConfig.ANALYSIS_SECONDS.size &&
            timing.timestampSeconds + TIME_EPSILON_SECONDS >=
            RppgTimingConfig.ANALYSIS_SECONDS[nextAnalysisIndex]
        ) {
            due += RppgTimingConfig.ANALYSIS_SECONDS[nextAnalysisIndex]
            nextAnalysisIndex += 1
        }
        val elapsedMillis = (timing.timestampSeconds * 1_000.0).toLong()
            .coerceAtMost(RppgTimingConfig.DEFAULT_DURATION_SECONDS * 1_000L)
        return RppgBvpAppendResult(
            segmentId = segmentId,
            elapsedMillis = elapsedMillis,
            sampleCount = samples.size,
            analysisSecondsDue = due,
            complete = timing.timestampSeconds + TIME_EPSILON_SECONDS >=
                RppgTimingConfig.DEFAULT_DURATION_SECONDS,
        )
    }

    @Synchronized
    fun snapshot(): List<TimedRppgSample> = samples.toList()

    @Synchronized
    fun currentSegmentId(): Long = segmentId

    @Synchronized
    fun currentDurationSeconds(): Double =
        if (samples.size >= 2) samples.last().timestampSeconds - samples.first().timestampSeconds else 0.0

    private fun currentResetSummary() = RppgSegmentResetSummary(
        segmentId = segmentId,
        discardedSampleCount = samples.size,
        discardedDurationSeconds = currentDurationSeconds(),
    )

    private fun clearCurrentSegment() {
        lastSourceTimestampNanos = null
        lastArrivalTimestampNanos = null
        resolvedElapsedSeconds = 0.0
        hasAcceptedFrame = false
        nextAnalysisIndex = 0
        samples.clear()
    }

    private companion object {
        const val NANOS_PER_SECOND = 1_000_000_000.0
        const val TIME_EPSILON_SECONDS = 1e-6
    }
}
