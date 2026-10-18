package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/** Fourth-order SciPy-style Butterworth band-pass (eight digital poles). */
internal object RppgButterworth {
    fun zeroPhaseBandPass(
        input: DoubleArray,
        sampleRateHz: Double,
        lowHz: Double,
        highHz: Double,
    ): DoubleArray? {
        if (
            input.size <= FILTER_PAD_LENGTH || sampleRateHz <= 0.0 || lowHz <= 0.0 ||
            highHz <= lowHz || highHz >= sampleRateHz / 2.0 || input.any { !it.isFinite() }
        ) {
            return null
        }
        return runCatching {
            val sections = designBandPass(sampleRateHz, lowHz, highHz)
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

    private fun designBandPass(
        sampleRateHz: Double,
        lowHz: Double,
        highHz: Double,
    ): List<Section> {
        val warpedLow = 2.0 * sampleRateHz * tan(PI * lowHz / sampleRateHz)
        val warpedHigh = 2.0 * sampleRateHz * tan(PI * highHz / sampleRateHz)
        val bandwidth = warpedHigh - warpedLow
        val center = sqrt(warpedLow * warpedHigh)
        val analogPoles = List(FILTER_ORDER) { index ->
            val angle = PI * (2.0 * index + FILTER_ORDER + 1.0) / (2.0 * FILTER_ORDER)
            Complex(cos(angle), sin(angle))
        }
        val digitalPoles = analogPoles.flatMap { pole ->
            val scaled = pole * bandwidth
            val discriminant = scaled * scaled - Complex(4.0 * center * center, 0.0)
            val root = discriminant.sqrt()
            listOf((scaled + root) / 2.0, (scaled - root) / 2.0)
        }.map { analogPole ->
            val twoFs = Complex(2.0 * sampleRateHz, 0.0)
            (twoFs + analogPole) / (twoFs - analogPole)
        }
        val positivePoles = digitalPoles
            .filter { it.imaginary >= -COMPLEX_EPSILON }
            .sortedBy { it.imaginary }
        require(positivePoles.size == FILTER_ORDER) { "Unexpected Butterworth pole pairing" }

        val zeroPairs = listOf(
            1.0 to 1.0,
            -1.0 to -1.0,
            1.0 to 1.0,
            -1.0 to -1.0,
        )
        val centerOmega = 2.0 * atan(center / (2.0 * sampleRateHz))
        val evaluationPoint = Complex(cos(centerOmega), sin(centerOmega))
        val allZeros = zeroPairs.flatMap { listOf(it.first, it.second) }
        val numeratorMagnitude = allZeros.fold(1.0) { product, zero ->
            product * (evaluationPoint - Complex(zero, 0.0)).magnitude()
        }
        val denominatorMagnitude = digitalPoles.fold(1.0) { product, pole ->
            product * (evaluationPoint - pole).magnitude()
        }
        val gain = denominatorMagnitude / numeratorMagnitude

        return positivePoles.mapIndexed { index, pole ->
            val zeros = zeroPairs[index]
            val sectionGain = if (index == 0) gain else 1.0
            Section(
                b0 = sectionGain,
                b1 = -sectionGain * (zeros.first + zeros.second),
                b2 = sectionGain * zeros.first * zeros.second,
                a1 = -2.0 * pole.real,
                a2 = pole.real * pole.real + pole.imaginary * pole.imaginary,
            )
        }
    }

    private fun applySections(input: DoubleArray, sections: List<Section>): DoubleArray =
        sections.fold(input) { values, section -> section.filter(values) }

    private fun oddReflectPad(input: DoubleArray, pad: Int): DoubleArray {
        val result = DoubleArray(input.size + pad * 2)
        for (index in 0 until pad) result[index] = 2.0 * input.first() - input[pad - index]
        input.copyInto(result, destinationOffset = pad)
        for (index in 0 until pad) {
            result[pad + input.size + index] =
                2.0 * input.last() - input[input.lastIndex - 1 - index]
        }
        return result
    }

    private data class Section(
        val b0: Double,
        val b1: Double,
        val b2: Double,
        val a1: Double,
        val a2: Double,
    ) {
        fun filter(input: DoubleArray): DoubleArray {
            val output = DoubleArray(input.size)
            val firstInput = input.first()
            val dcGain = (b0 + b1 + b2) / (1.0 + a1 + a2)
            val steadyOutput = dcGain * firstInput
            var state1 = steadyOutput - b0 * firstInput
            var state2 = b2 * firstInput - a2 * steadyOutput
            input.forEachIndexed { index, value ->
                val result = b0 * value + state1
                state1 = b1 * value - a1 * result + state2
                state2 = b2 * value - a2 * result
                output[index] = result
            }
            return output
        }
    }

    private data class Complex(val real: Double, val imaginary: Double) {
        operator fun plus(other: Complex) = Complex(real + other.real, imaginary + other.imaginary)
        operator fun minus(other: Complex) = Complex(real - other.real, imaginary - other.imaginary)
        operator fun times(value: Double) = Complex(real * value, imaginary * value)
        operator fun times(other: Complex) = Complex(
            real * other.real - imaginary * other.imaginary,
            real * other.imaginary + imaginary * other.real,
        )
        operator fun div(value: Double) = Complex(real / value, imaginary / value)
        operator fun div(other: Complex): Complex {
            val denominator = other.real * other.real + other.imaginary * other.imaginary
            return Complex(
                (real * other.real + imaginary * other.imaginary) / denominator,
                (imaginary * other.real - real * other.imaginary) / denominator,
            )
        }

        fun magnitude(): Double = hypot(real, imaginary)

        fun sqrt(): Complex {
            val magnitude = magnitude()
            val realPart = sqrt((magnitude + real) / 2.0)
            val imaginaryPart = kotlin.math.sign(imaginary) * sqrt((magnitude - real) / 2.0)
            return Complex(realPart, imaginaryPart)
        }
    }

    private const val FILTER_ORDER = 4
    private const val FILTER_PAD_LENGTH = 27
    private const val COMPLEX_EPSILON = 1e-10
}
