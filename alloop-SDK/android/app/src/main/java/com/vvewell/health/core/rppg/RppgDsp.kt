package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sqrt
import kotlin.math.tan
import org.jtransforms.fft.DoubleFFT_1D

internal data class RppgSpectrum(
    val frequenciesHz: DoubleArray,
    val power: DoubleArray,
    val resolutionHz: Double,
)

internal object RppgDsp {
    fun linearDetrend(input: DoubleArray): DoubleArray {
        val count = input.size
        val meanX = (count - 1) / 2.0
        val meanY = input.average()
        var numerator = 0.0
        var denominator = 0.0
        input.forEachIndexed { index, value ->
            val dx = index - meanX
            numerator += dx * (value - meanY)
            denominator += dx * dx
        }
        val slope = if (denominator == 0.0) 0.0 else numerator / denominator
        return DoubleArray(count) { index -> input[index] - (meanY + slope * (index - meanX)) }
    }

    fun zScore(input: DoubleArray): DoubleArray? {
        if (input.isEmpty()) return null
        val mean = input.average()
        val variance = input.sumOf { value ->
            val centered = value - mean
            centered * centered
        } / input.size
        val standardDeviation = sqrt(variance)
        if (!standardDeviation.isFinite() || standardDeviation < MIN_STANDARD_DEVIATION) return null
        return DoubleArray(input.size) { index -> (input[index] - mean) / standardDeviation }
    }

    /** Third-order Butterworth low-pass followed forward and backward for zero phase. */
    fun zeroPhaseButterworthLowPass(
        input: DoubleArray,
        sampleRateHz: Double,
        cutoffHz: Double,
    ): DoubleArray? {
        if (
            input.size <= FILTER_PAD_LENGTH || sampleRateHz <= 0.0 || cutoffHz <= 0.0 ||
            cutoffHz >= sampleRateHz / 2.0
        ) {
            return null
        }
        return runCatching {
            val sections = thirdOrderLowPassSections(sampleRateHz, cutoffHz)
            val pad = FILTER_PAD_LENGTH.coerceAtMost(input.lastIndex)
            val padded = oddReflectPad(input, pad)
            var filtered = applySections(padded, sections)
            filtered.reverse()
            filtered = applySections(filtered, sections)
            filtered.reverse()
            filtered.copyOfRange(pad, pad + input.size)
                .takeIf { values -> values.all(Double::isFinite) }
        }.getOrNull()
    }

    /** Raw rFFT without a window, matching the Python RR reference path. */
    fun rawPowerSpectrum(input: DoubleArray, sampleRateHz: Double): RppgSpectrum? {
        if (input.size < 2 || sampleRateHz <= 0.0 || input.any { !it.isFinite() }) return null
        return runCatching {
            val complex = DoubleArray(input.size * 2)
            input.copyInto(complex, endIndex = input.size)
            DoubleFFT_1D(input.size.toLong()).realForwardFull(complex)
            val bins = input.size / 2 + 1
            val resolution = sampleRateHz / input.size
            val frequencies = DoubleArray(bins) { index -> index * resolution }
            val power = DoubleArray(bins) { index ->
                val real = complex[index * 2]
                val imaginary = complex[index * 2 + 1]
                real * real + imaginary * imaginary
            }
            RppgSpectrum(frequencies, power, resolution)
        }.getOrNull()
    }

    private fun thirdOrderLowPassSections(
        sampleRateHz: Double,
        cutoffHz: Double,
    ): List<FilterSection> {
        val k = tan(PI * cutoffHz / sampleRateHz)
        val firstNorm = 1.0 / (1.0 + k)
        val first = FilterSection(
            b0 = k * firstNorm,
            b1 = k * firstNorm,
            b2 = 0.0,
            a1 = (k - 1.0) * firstNorm,
            a2 = 0.0,
        )

        // The complex pole pair of a third-order Butterworth prototype has Q=1.
        val secondNorm = 1.0 / (1.0 + k + k * k)
        val second = FilterSection(
            b0 = k * k * secondNorm,
            b1 = 2.0 * k * k * secondNorm,
            b2 = k * k * secondNorm,
            a1 = 2.0 * (k * k - 1.0) * secondNorm,
            a2 = (1.0 - k + k * k) * secondNorm,
        )
        return listOf(first, second)
    }

    private fun oddReflectPad(input: DoubleArray, pad: Int): DoubleArray {
        val result = DoubleArray(input.size + pad * 2)
        for (index in 0 until pad) {
            result[index] = 2.0 * input.first() - input[pad - index]
        }
        input.copyInto(result, destinationOffset = pad)
        for (index in 0 until pad) {
            result[pad + input.size + index] =
                2.0 * input.last() - input[input.lastIndex - 1 - index]
        }
        return result
    }

    private fun applySections(
        input: DoubleArray,
        sections: List<FilterSection>,
    ): DoubleArray = sections.fold(input) { values, section -> section.filter(values) }

    private data class FilterSection(
        val b0: Double,
        val b1: Double,
        val b2: Double,
        val a1: Double,
        val a2: Double,
    ) {
        fun filter(input: DoubleArray): DoubleArray {
            val output = DoubleArray(input.size)
            var x1 = 0.0
            var x2 = 0.0
            var y1 = 0.0
            var y2 = 0.0
            input.forEachIndexed { index, x0 ->
                val y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
                output[index] = y0
                x2 = x1
                x1 = x0
                y2 = y1
                y1 = y0
            }
            return output
        }
    }

    private const val MIN_STANDARD_DEVIATION = 1e-6
    private const val FILTER_PAD_LENGTH = 12
}
