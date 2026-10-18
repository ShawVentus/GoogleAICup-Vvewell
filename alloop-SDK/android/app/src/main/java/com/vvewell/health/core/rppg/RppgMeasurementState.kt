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
    val message: String = "准备测量",
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
                message = "正在准备检测…",
            ),
        )
    }

    @Synchronized
    internal fun requestStart(): RppgSessionTransition = when (state.phase) {
        RppgPhase.PreviewPreparing -> transition(
            state.copy(
                phase = RppgPhase.StartPending,
                message = "正在准备检测，准备完成后将自动开始",
            ),
        )
        RppgPhase.PreviewReady -> transition(
            state.copy(
                phase = RppgPhase.StartPending,
                message = "正在建立正式测量…",
            ),
            beginOfficialMeasurement = true,
        )
        else -> RppgSessionTransition(state)
    }

    @Synchronized
    internal fun onPrerollReady(): RppgSessionTransition = when (state.phase) {
        RppgPhase.PreviewPreparing -> transition(
            state.copy(phase = RppgPhase.PreviewReady, message = "准备完成"),
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
            update(state.copy(message = "正在准备检测，准备完成后将自动开始"))
        } else {
            state
        }

    @Synchronized
    internal fun markOfficialMeasurementStarted(): RppgMeasurementState =
        if (state.phase == RppgPhase.StartPending) {
            update(
                RppgMeasurementState(
                    phase = RppgPhase.Aligning,
                    message = "请将脸放入椭圆并保持稳定",
                ),
            )
        } else {
            state
        }

    @Synchronized
    fun onPrerollUnready(): RppgMeasurementState = if (state.phase == RppgPhase.PreviewReady) {
        update(state.copy(phase = RppgPhase.PreviewPreparing, message = "正在准备检测…"))
    } else {
        state
    }

    @Synchronized
    fun markPreparationSlow(): RppgMeasurementState = when (state.phase) {
        RppgPhase.PreviewPreparing -> update(
            state.copy(message = "准备时间较长，请保持正脸、稳定手机并改善光线"),
        )
        RppgPhase.StartPending -> update(
            state.copy(message = "准备时间较长，请保持正脸、稳定手机并改善光线；准备完成后将自动开始"),
        )
        else -> state
    }

    @Synchronized
    fun onFirstSample(): RppgMeasurementState {
        if (state.phase != RppgPhase.Aligning) return state
        return update(state.copy(phase = RppgPhase.Collecting, message = "正在采集信号，请保持稳定"))
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
            RppgPhase.Aligning -> "请将脸放入椭圆并保持稳定"
            RppgPhase.Collecting -> "正在采集信号，请保持稳定"
            else -> if (state.result == null && state.respiration == null) "估计中…" else "初步估计，持续更新中"
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
            message = "人脸信号中断，请保持稳定并重新采集",
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
                "信号质量不足，继续保持稳定"
            } else {
                "初步估计，持续更新中"
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
                message = if (accepted) "测量完成" else "信号质量不足，请改善光线后重试",
            ),
        )
    }

    @Synchronized
    fun permissionDenied(): RppgMeasurementState = update(
        RppgMeasurementState(
            phase = RppgPhase.PermissionDenied,
            message = "需要摄像头权限才能测量",
        ),
    )

    @Synchronized
    fun fail(message: String): RppgMeasurementState = update(
        state.copy(
            phase = RppgPhase.Error,
            heartRateEstimate = null,
            respirationEstimate = null,
            syntheticVitals = null,
            message = "测量失败：$message",
        ),
    )

    @Synchronized
    fun cancel(): RppgMeasurementState = update(
        state.copy(
            phase = RppgPhase.Cancelled,
            syntheticVitals = null,
            message = "测量已取消",
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
