package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.atan2
import org.jtransforms.fft.DoubleFFT_1D

internal data class RppgAnalyticSignal(
    val real: DoubleArray,
    val imaginary: DoubleArray,
)

internal object RppgHilbert {
    fun analyticSignal(input: DoubleArray): RppgAnalyticSignal? {
        if (input.size < 2 || input.any { !it.isFinite() }) return null
        return runCatching {
            val n = input.size
            val spectrum = DoubleArray(n * 2)
            input.forEachIndexed { index, value -> spectrum[index * 2] = value }
            val fft = DoubleFFT_1D(n.toLong())
            fft.complexForward(spectrum)
            for (bin in 0 until n) {
                val multiplier = when {
                    bin == 0 -> 1.0
                    n % 2 == 0 && bin == n / 2 -> 1.0
                    bin <= (n - 1) / 2 -> 2.0
                    else -> 0.0
                }
                spectrum[bin * 2] *= multiplier
                spectrum[bin * 2 + 1] *= multiplier
            }
            fft.complexInverse(spectrum, true)
            val real = DoubleArray(n) { spectrum[it * 2] }
            val imaginary = DoubleArray(n) { spectrum[it * 2 + 1] }
            RppgAnalyticSignal(real, imaginary)
                .takeIf { result -> result.real.all(Double::isFinite) && result.imaginary.all(Double::isFinite) }
        }.getOrNull()
    }

    fun unwrappedPhase(analytic: RppgAnalyticSignal): DoubleArray? {
        if (
            analytic.real.size != analytic.imaginary.size || analytic.real.isEmpty() ||
            analytic.real.any { !it.isFinite() } || analytic.imaginary.any { !it.isFinite() }
        ) {
            return null
        }
        val phase = DoubleArray(analytic.real.size) { index ->
            atan2(analytic.imaginary[index], analytic.real[index])
        }
        var correction = 0.0
        var previousRaw = phase[0]
        for (index in 1 until phase.size) {
            val currentRaw = phase[index]
            val delta = currentRaw - previousRaw
            when {
                delta > PI -> correction -= TWO_PI
                delta < -PI -> correction += TWO_PI
            }
            phase[index] = currentRaw + correction
            previousRaw = currentRaw
        }
        return phase
    }

    fun instantaneousFrequency(input: DoubleArray, sampleRateHz: Double): DoubleArray? {
        if (sampleRateHz <= 0.0 || !sampleRateHz.isFinite()) return null
        val analytic = analyticSignal(input) ?: return null
        val phase = unwrappedPhase(analytic) ?: return null
        return DoubleArray(phase.lastIndex) { index ->
            (phase[index + 1] - phase[index]) * sampleRateHz / TWO_PI
        }.takeIf { values -> values.all(Double::isFinite) }
    }

    private const val TWO_PI = 2.0 * PI
}

internal object RppgOutlierCleaner {
    fun populationSigma(input: DoubleArray, rounds: Int = 3, sigma: Double = 2.0): DoubleArray {
        var values = input.filter(Double::isFinite).toDoubleArray()
        repeat(rounds) {
            if (values.size < 2) return values
            val mean = values.average()
            val variance = values.sumOf { value ->
                val centered = value - mean
                centered * centered
            } / values.size
            val standardDeviation = kotlin.math.sqrt(variance)
            if (standardDeviation < MIN_STANDARD_DEVIATION) return values
            val filtered = values.filter { value ->
                kotlin.math.abs(value - mean) <= sigma * standardDeviation
            }.toDoubleArray()
            if (filtered.isEmpty()) return values
            values = filtered
        }
        return values
    }

    private const val MIN_STANDARD_DEVIATION = 1e-8
}
