package com.vvewell.health.core.rppg

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

internal data class UniformRppgSignal(
    val values: DoubleArray,
    val sampleRateHz: Double,
    val diagnostics: MetricDiagnostics,
)

internal sealed interface RppgResampleOutcome {
    data class Success(val signal: UniformRppgSignal) : RppgResampleOutcome
    data class Rejected(
        val reason: MetricRejectionReason,
        val diagnostics: MetricDiagnostics,
    ) : RppgResampleOutcome
}

/** Shared timestamp validation and interpolation for both HR and RR. */
internal object RppgSignalResampler {
    fun resample(input: List<TimedRppgSample>): RppgResampleOutcome {
        if (input.size < MIN_INPUT_SAMPLES) {
            return rejected(MetricRejectionReason.InsufficientSamples, input.size)
        }
        if (input.any { !it.timestampSeconds.isFinite() || !it.value.isFinite() }) {
            return rejected(MetricRejectionReason.NonFiniteInput, input.size)
        }

        val deltas = DoubleArray(input.lastIndex) { index ->
            input[index + 1].timestampSeconds - input[index].timestampSeconds
        }
        if (deltas.any { it <= 0.0 || !it.isFinite() }) {
            return rejected(MetricRejectionReason.NonIncreasingTimestamp, input.size)
        }
        val duration = input.last().timestampSeconds - input.first().timestampSeconds
        if (duration <= 0.0 || !duration.isFinite()) {
            return rejected(MetricRejectionReason.NonIncreasingTimestamp, input.size)
        }

        val medianGap = median(deltas)
        val medianSampleRate = 1.0 / medianGap
        val spanSampleRate = (input.size - 1) / duration
        val targetSampleRate = min(
            MAX_TARGET_SAMPLE_RATE_HZ,
            min(medianSampleRate, spanSampleRate),
        )
        val maximumGap = deltas.maxOrNull() ?: 0.0
        val allowedGap = min(
            ABSOLUTE_MAX_INTERPOLATION_GAP_SECONDS,
            max(BASE_MAX_INTERPOLATION_GAP_SECONDS, medianGap * MAX_INTERPOLATION_GAP_MULTIPLIER),
        )
        val timeQuality = timeQuality(
            deltas = deltas,
            medianGap = medianGap,
            spanSampleRate = spanSampleRate,
            medianSampleRate = medianSampleRate,
            maximumGap = maximumGap,
            allowedGap = allowedGap,
        )
        val diagnostics = MetricDiagnostics(
            sampleCount = input.size,
            durationSeconds = duration,
            medianSampleRateHz = medianSampleRate,
            spanSampleRateHz = spanSampleRate,
            targetSampleRateHz = targetSampleRate,
            medianGapSeconds = medianGap,
            maximumGapSeconds = maximumGap,
            allowedGapSeconds = allowedGap,
            timeQuality = timeQuality,
        )
        if (maximumGap > allowedGap) {
            return RppgResampleOutcome.Rejected(
                reason = MetricRejectionReason.ExcessiveLocalGap,
                diagnostics = diagnostics,
            )
        }
        if (targetSampleRate <= 0.0 || !targetSampleRate.isFinite()) {
            return RppgResampleOutcome.Rejected(
                reason = MetricRejectionReason.SampleRateTooLow,
                diagnostics = diagnostics,
            )
        }

        // Use a half-open uniform grid [first, last). With N samples at fs, the
        // FFT record length is N/fs and physiological boundary bins remain exact.
        val outputCount = ceil(duration * targetSampleRate - GRID_EPSILON).toInt()
        if (outputCount < MIN_INPUT_SAMPLES) {
            return RppgResampleOutcome.Rejected(
                reason = MetricRejectionReason.InsufficientSamples,
                diagnostics = diagnostics,
            )
        }
        var right = 1
        val firstTime = input.first().timestampSeconds
        val output = DoubleArray(outputCount) { index ->
            val time = firstTime + index / targetSampleRate
            while (right < input.lastIndex && input[right].timestampSeconds < time) right += 1
            val before = input[right - 1]
            val after = input[right]
            val span = after.timestampSeconds - before.timestampSeconds
            val fraction = ((time - before.timestampSeconds) / span).coerceIn(0.0, 1.0)
            before.value + (after.value - before.value) * fraction
        }
        return RppgResampleOutcome.Success(
            UniformRppgSignal(
                values = output,
                sampleRateHz = targetSampleRate,
                diagnostics = diagnostics.copy(sampleCount = output.size),
            ),
        )
    }

    private fun timeQuality(
        deltas: DoubleArray,
        medianGap: Double,
        spanSampleRate: Double,
        medianSampleRate: Double,
        maximumGap: Double,
        allowedGap: Double,
    ): Double {
        val medianAbsoluteDeviation = median(
            DoubleArray(deltas.size) { index -> abs(deltas[index] - medianGap) },
        )
        val jitterRatio = medianAbsoluteDeviation / medianGap
        val jitterQuality = 1.0 - ramp(jitterRatio, 0.05, 0.50)
        val densityQuality = (spanSampleRate / medianSampleRate).coerceIn(0.0, 1.0)
        val gapQuality = 1.0 - ramp(maximumGap / allowedGap, 0.5, 1.0)
        return (0.4 * jitterQuality + 0.3 * densityQuality + 0.3 * gapQuality)
            .coerceIn(0.0, 1.0)
    }

    internal fun median(values: DoubleArray): Double {
        require(values.isNotEmpty()) { "Median requires at least one value" }
        val sorted = values.sortedArray()
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 0) {
            (sorted[middle - 1] + sorted[middle]) / 2.0
        } else {
            sorted[middle]
        }
    }

    private fun rejected(reason: MetricRejectionReason, sampleCount: Int) =
        RppgResampleOutcome.Rejected(
            reason = reason,
            diagnostics = MetricDiagnostics(sampleCount = sampleCount),
        )

    private const val MIN_INPUT_SAMPLES = 3
    private const val MAX_TARGET_SAMPLE_RATE_HZ = 30.0
    private const val BASE_MAX_INTERPOLATION_GAP_SECONDS = 0.5
    private const val MAX_INTERPOLATION_GAP_MULTIPLIER = 3.0
    private const val ABSOLUTE_MAX_INTERPOLATION_GAP_SECONDS = 0.9
    private const val GRID_EPSILON = 1e-9
}
