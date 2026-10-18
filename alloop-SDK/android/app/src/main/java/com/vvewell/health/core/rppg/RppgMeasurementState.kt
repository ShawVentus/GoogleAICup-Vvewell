package com.vvewell.health.core.rppg

import com.alloop.blue.test.BuildConfig

enum class RppgPhase {
    Ready,
    PreviewPreparing,
    PreviewReady,
    StartPending,
    Aligning,
    Collecting,
    Estimating,
    Completed,
    LowQuality,
    PermissionDenied,
    Error,
    Cancelled,
}

data class RppgMeasurementState(
    val phase: RppgPhase = RppgPhase.Ready,
    val elapsedMillis: Long = 0L,
    val heartRateEstimate: MetricEstimate? = null,
    val respirationEstimate: MetricEstimate? = null,
    val syntheticVitals: SyntheticVitals? = null,
    val message: String = "Ready to measure",
) {
    val result: RppgResult?
        get() = heartRateEstimate?.toHeartRateResult()

    val respiration: RespirationResult?
        get() = respirationEstimate?.toRespirationResult()

    val pipelineActive: Boolean
        get() = phase in setOf(
            RppgPhase.PreviewPreparing,
            RppgPhase.PreviewReady,
            RppgPhase.StartPending,
            RppgPhase.Aligning,
            RppgPhase.Collecting,
            RppgPhase.Estimating,
        )

    val measuring: Boolean
        get() = phase in setOf(RppgPhase.Aligning, RppgPhase.Collecting, RppgPhase.Estimating)

    val canRequestStart: Boolean
        get() = phase in setOf(
            RppgPhase.PreviewPreparing,
            RppgPhase.PreviewReady,
            RppgPhase.PermissionDenied,
            RppgPhase.Cancelled,
        )

    /** Backwards-compatible name for lifecycle/test callers. */
    val running: Boolean
        get() = pipelineActive

    val elapsedSeconds: Int
        get() = (elapsedMillis / 1_000L).toInt()

    val progress: Float
        get() = (elapsedMillis / MEASUREMENT_MILLIS.toFloat()).coerceIn(0f, 1f)

    val preliminary: Boolean
        get() = phase == RppgPhase.Estimating && elapsedMillis < MEASUREMENT_MILLIS

    companion object {
        const val MEASUREMENT_MILLIS = RppgTimingConfig.DEFAULT_DURATION_SECONDS * 1_000L
    }
}

/**
 * Pure state holder for one measurement round. It intentionally owns no Android
 * objects so reset and terminal-state boundaries can be unit tested.
 */
class RppgMeasurementSession internal constructor(
    private val syntheticVitalsFactory: SyntheticVitalsFactory,
) {
    constructor() : this(SyntheticVitalsFactory(enabled = BuildConfig.DEBUG))

    @Volatile
    var state: RppgMeasurementState = RppgMeasurementState()
        private set

    @Synchronized
    fun beginPreview(): RppgMeasurementState {
        return update(
            RppgMeasurementState(
                phase = RppgPhase.PreviewPreparing,
                message = "Preparing measurement…",
            ),
        )
    }

    @Synchronized
    internal fun requestStart(): RppgSessionTransition = when (state.phase) {
        RppgPhase.PreviewPreparing -> transition(
            state.copy(
                phase = RppgPhase.StartPending,
                message = "Preparing measurement. It will start automatically when ready.",
            ),
        )
        RppgPhase.PreviewReady -> transition(
            state.copy(
                phase = RppgPhase.StartPending,
                message = "Starting measurement…",
            ),
            beginOfficialMeasurement = true,
        )
        else -> RppgSessionTransition(state)
    }

    @Synchronized
    internal fun onPrerollReady(): RppgSessionTransition = when (state.phase) {
        RppgPhase.PreviewPreparing -> transition(
            state.copy(phase = RppgPhase.PreviewReady, message = "Ready"),
        )
        RppgPhase.StartPending -> transition(
            state,
            beginOfficialMeasurement = true,
        )
        else -> RppgSessionTransition(state)
    }

    @Synchronized
    internal fun deferOfficialStartUntilReady(): RppgMeasurementState =
        if (state.phase == RppgPhase.StartPending) {
            update(state.copy(message = "Preparing measurement. It will start automatically when ready."))
        } else {
            state
        }

    @Synchronized
    internal fun markOfficialMeasurementStarted(): RppgMeasurementState =
        if (state.phase == RppgPhase.StartPending) {
            update(
                RppgMeasurementState(
                    phase = RppgPhase.Aligning,
                    message = "Position your face inside the oval and hold still",
                ),
            )
        } else {
            state
        }

    @Synchronized
    fun onPrerollUnready(): RppgMeasurementState = if (state.phase == RppgPhase.PreviewReady) {
        update(state.copy(phase = RppgPhase.PreviewPreparing, message = "Preparing measurement…"))
    } else {
        state
    }

    @Synchronized
    fun markPreparationSlow(): RppgMeasurementState = when (state.phase) {
        RppgPhase.PreviewPreparing -> update(
            state.copy(message = "Preparation is taking longer. Face forward, steady your phone, and improve the lighting."),
        )
        RppgPhase.StartPending -> update(
            state.copy(message = "Preparation is taking longer. Face forward, steady your phone, and improve the lighting. Measurement will start automatically when ready."),
        )
        else -> state
    }

    @Synchronized
    fun onFirstSample(): RppgMeasurementState {
        if (state.phase != RppgPhase.Aligning) return state
        return update(state.copy(phase = RppgPhase.Collecting, message = "Collecting signal. Hold still."))
    }

    @Synchronized
    fun updateEffectiveElapsed(elapsedMillis: Long): RppgMeasurementState {
        if (!state.measuring) return state
        val boundedElapsedMillis = elapsedMillis.coerceAtLeast(0L)
            .coerceAtMost(RppgMeasurementState.MEASUREMENT_MILLIS)
        val phase = when {
            boundedElapsedMillis >= PRELIMINARY_MILLIS -> RppgPhase.Estimating
            state.phase == RppgPhase.Aligning -> RppgPhase.Aligning
            else -> RppgPhase.Collecting
        }
        val message = when (phase) {
            RppgPhase.Aligning -> "Position your face inside the oval and hold still"
            RppgPhase.Collecting -> "Collecting signal. Hold still."
            else -> if (state.result == null && state.respiration == null) "Estimating…" else "Preliminary estimates are updating"
        }
        return update(state.copy(phase = phase, elapsedMillis = boundedElapsedMillis, message = message))
    }

    @Synchronized
    fun restartContinuousSegment(): RppgMeasurementState = update(
        state.copy(
            phase = RppgPhase.Aligning,
            elapsedMillis = 0L,
            heartRateEstimate = null,
            respirationEstimate = null,
            syntheticVitals = null,
            message = "Face signal interrupted. Hold still while the signal is collected again.",
        ),
    )

    @Synchronized
    fun updateEstimate(
        heartRate: MetricEstimate,
        respiration: MetricEstimate,
    ): RppgMeasurementState = update(
        state.copy(
            heartRateEstimate = heartRate,
            respirationEstimate = respiration,
            message = if (!heartRate.available && !respiration.available) {
                "Insufficient signal quality. Keep holding still."
            } else {
                "Preliminary estimates are updating"
            },
        ),
    )

    @Synchronized
    fun complete(
        heartRate: MetricEstimate,
        respiration: MetricEstimate,
    ): RppgMeasurementState {
        val accepted = heartRate.available || respiration.available
        return update(
            state.copy(
                phase = if (accepted) RppgPhase.Completed else RppgPhase.LowQuality,
                elapsedMillis = RppgMeasurementState.MEASUREMENT_MILLIS,
                heartRateEstimate = heartRate,
                respirationEstimate = respiration,
                syntheticVitals = if (accepted) {
                    state.syntheticVitals ?: syntheticVitalsFactory.create()
                } else {
                    null
                },
                message = if (accepted) "Measurement complete" else "Insufficient signal quality. Improve the lighting and try again.",
            ),
        )
    }

    @Synchronized
    fun permissionDenied(): RppgMeasurementState = update(
        RppgMeasurementState(
            phase = RppgPhase.PermissionDenied,
            message = "Camera permission is required to measure",
        ),
    )

    @Synchronized
    fun fail(message: String): RppgMeasurementState = update(
        state.copy(
            phase = RppgPhase.Error,
            heartRateEstimate = null,
            respirationEstimate = null,
            syntheticVitals = null,
            message = "Measurement failed: $message",
        ),
    )

    @Synchronized
    fun cancel(): RppgMeasurementState = update(
        state.copy(
            phase = RppgPhase.Cancelled,
            syntheticVitals = null,
            message = "Measurement cancelled",
        ),
    )

    private fun update(next: RppgMeasurementState): RppgMeasurementState {
        state = next
        return next
    }

    private fun transition(
        next: RppgMeasurementState,
        beginOfficialMeasurement: Boolean = false,
    ): RppgSessionTransition = RppgSessionTransition(
        state = update(next),
        beginOfficialMeasurement = beginOfficialMeasurement,
    )

    private companion object {
        const val PRELIMINARY_MILLIS = RppgTimingConfig.FIRST_ANALYSIS_SECONDS * 1_000L
    }
}

internal data class RppgSessionTransition(
    val state: RppgMeasurementState,
    val beginOfficialMeasurement: Boolean = false,
)
