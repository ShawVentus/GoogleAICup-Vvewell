package com.vvewell.health.core.rppg

import kotlin.math.abs
import kotlin.math.max

internal data class RppgEmdConfig(
    val mirroredExtremaCount: Int = 2,
    val standardDeviationThreshold: Double = 0.2,
    val scaledVarianceThreshold: Double = 0.001,
    val energyRatioThreshold: Double = 0.2,
    val residueRangeThreshold: Double = 0.001,
    val residueAbsoluteSumThreshold: Double = 0.005,
    val maximumSiftIterations: Int = 1_000,
    val maximumImfs: Int = 16,
)

internal enum class RppgEmdFailure {
    NonFiniteInput,
    InsufficientExtrema,
    SplineFailure,
    DidNotConverge,
    NumericalFailure,
}

internal sealed interface RppgEmdOutcome {
    val converged: Boolean

    data class Success(
        val imfs: List<DoubleArray>,
        val residue: DoubleArray,
        val siftIterations: List<Int>,
        override val converged: Boolean = true,
    ) : RppgEmdOutcome

    data class Failure(
        val reason: RppgEmdFailure,
        val completedImfs: Int,
        val siftIterations: List<Int>,
        override val converged: Boolean = false,
    ) : RppgEmdOutcome
}

/**
 * Pure Kotlin EMD with explicit EMD-signal 1.9.0-aligned thresholds,
 * discrete extrema, mirrored endpoints, and cubic spline envelopes.
 */
internal class RppgEmd(
    private val config: RppgEmdConfig = RppgEmdConfig(),
) {
    fun decompose(input: DoubleArray): RppgEmdOutcome {
        if (input.size < MIN_SIGNAL_SIZE || input.any { !it.isFinite() }) {
            return RppgEmdOutcome.Failure(
                reason = if (input.any { !it.isFinite() }) {
                    RppgEmdFailure.NonFiniteInput
                } else {
                    RppgEmdFailure.InsufficientExtrema
                },
                completedImfs = 0,
                siftIterations = emptyList(),
            )
        }

        val imfs = mutableListOf<DoubleArray>()
        val iterations = mutableListOf<Int>()
        var residue = input.copyOf()

        while (true) {
            val residueExtrema = findExtrema(residue)
            if (residueExtrema.totalCount <= MIN_EXTREMA_FOR_SIFTING) break
            if (imfs.size >= config.maximumImfs) {
                return failure(RppgEmdFailure.DidNotConverge, imfs, iterations)
            }

            var protoImf = residue.copyOf()
            var converged = false
            var completedIterations = 0
            for (iteration in 1..config.maximumSiftIterations) {
                completedIterations = iteration
                val extrema = findExtrema(protoImf)
                if (extrema.totalCount <= MIN_EXTREMA_FOR_SIFTING) break
                val upper = envelope(protoImf, extrema.maxima)
                    ?: return failure(RppgEmdFailure.SplineFailure, imfs, iterations)
                val lower = envelope(protoImf, extrema.minima)
                    ?: return failure(RppgEmdFailure.SplineFailure, imfs, iterations)
                val old = protoImf
                val next = DoubleArray(old.size) { index ->
                    old[index] - 0.5 * (upper[index] + lower[index])
                }
                if (next.any { !it.isFinite() }) {
                    return failure(RppgEmdFailure.NumericalFailure, imfs, iterations)
                }

                val nextExtrema = findExtrema(next)
                val shapeIsImf = abs(nextExtrema.totalCount - nextExtrema.zeroCrossings) < 2
                if (shapeIsImf && hasConverged(next, old, extrema)) {
                    protoImf = next
                    converged = true
                    break
                }
                protoImf = next
            }

            if (!converged) {
                return failure(RppgEmdFailure.DidNotConverge, imfs, iterations + completedIterations)
            }
            imfs += protoImf
            iterations += completedIterations
            residue = DoubleArray(input.size) { index -> input[index] - imfs.sumOf { it[index] } }
            if (residue.any { !it.isFinite() }) {
                return failure(RppgEmdFailure.NumericalFailure, imfs, iterations)
            }
            if (globalStop(residue)) break
        }

        if (imfs.isEmpty()) {
            return failure(RppgEmdFailure.InsufficientExtrema, imfs, iterations)
        }
        return RppgEmdOutcome.Success(
            imfs = imfs.map(DoubleArray::copyOf),
            residue = residue.copyOf(),
            siftIterations = iterations.toList(),
        )
    }

    private fun failure(
        reason: RppgEmdFailure,
        imfs: List<DoubleArray>,
        iterations: List<Int>,
    ) = RppgEmdOutcome.Failure(reason, imfs.size, iterations.toList())

    private fun globalStop(residue: DoubleArray): Boolean =
        (residue.maxOrNull()!! - residue.minOrNull()!!) < config.residueRangeThreshold ||
            residue.sumOf(::abs) < config.residueAbsoluteSumThreshold

    private fun hasConverged(
        next: DoubleArray,
        old: DoubleArray,
        extrema: Extrema,
    ): Boolean {
        if (extrema.maxima.any { old[it] < 0.0 } || extrema.minima.any { old[it] > 0.0 }) return false
        val nextEnergy = next.sumOf { it * it }
        if (nextEnergy < MIN_IMF_ENERGY) return false
        var differenceEnergy = 0.0
        var standardDeviation = 0.0
        for (index in next.indices) {
            val difference = next[index] - old[index]
            differenceEnergy += difference * difference
            val denominator = next[index]
            standardDeviation += if (abs(denominator) < DIVISION_EPSILON) {
                if (abs(difference) < DIVISION_EPSILON) 0.0 else Double.POSITIVE_INFINITY
            } else {
                val ratio = difference / denominator
                ratio * ratio
            }
        }
        val oldRange = (old.maxOrNull()!! - old.minOrNull()!!).coerceAtLeast(DIVISION_EPSILON)
        val oldEnergy = old.sumOf { it * it }.coerceAtLeast(DIVISION_EPSILON)
        val scaledVariance = differenceEnergy / oldRange
        val energyRatio = differenceEnergy / oldEnergy
        return scaledVariance < config.scaledVarianceThreshold ||
            standardDeviation < config.standardDeviationThreshold ||
            energyRatio < config.energyRatioThreshold
    }

    private fun envelope(signal: DoubleArray, extrema: IntArray): DoubleArray? {
        if (extrema.isEmpty()) return null
        val mirrorCount = config.mirroredExtremaCount.coerceAtMost(extrema.size)
        val positions = ArrayList<Double>(extrema.size + mirrorCount * 2)
        val values = ArrayList<Double>(positions.size)
        for (index in extrema.take(mirrorCount).asReversed()) {
            positions += -index.toDouble()
            values += signal[index]
        }
        extrema.forEach { index ->
            positions += index.toDouble()
            values += signal[index]
        }
        val rightEdge = signal.lastIndex.toDouble()
        for (index in extrema.takeLast(mirrorCount).asReversed()) {
            positions += 2.0 * rightEdge - index
            values += signal[index]
        }
        val distinct = positions.indices.filter { index ->
            index == 0 || positions[index] > positions[index - 1]
        }
        if (distinct.size < 2) return null
        val x = DoubleArray(distinct.size) { positions[distinct[it]] }
        val y = DoubleArray(distinct.size) { values[distinct[it]] }
        return RppgCubicSpline.interpolate(x, y, signal.size)
    }

    internal fun findExtrema(signal: DoubleArray): Extrema {
        val maxima = mutableListOf<Int>()
        val minima = mutableListOf<Int>()
        var index = 1
        while (index < signal.lastIndex) {
            var plateauEnd = index
            while (plateauEnd < signal.lastIndex && signal[plateauEnd + 1] == signal[index]) {
                plateauEnd += 1
            }
            val left = signal[index - 1]
            val value = signal[index]
            val right = if (plateauEnd < signal.lastIndex) signal[plateauEnd + 1] else value
            val center = ((index + plateauEnd) / 2.0).toInt()
            when {
                value > left && value > right -> maxima += center
                value < left && value < right -> minima += center
            }
            index = max(index + 1, plateauEnd + 1)
        }
        return Extrema(
            maxima = maxima.toIntArray(),
            minima = minima.toIntArray(),
            zeroCrossings = countZeroCrossings(signal),
        )
    }

    private fun countZeroCrossings(signal: DoubleArray): Int {
        var count = 0
        var index = 0
        while (index < signal.lastIndex) {
            if (signal[index] == 0.0) {
                var end = index
                while (end < signal.lastIndex && signal[end + 1] == 0.0) end += 1
                count += 1
                index = end + 1
            } else {
                if (signal[index] * signal[index + 1] < 0.0) count += 1
                index += 1
            }
        }
        return count
    }

    internal data class Extrema(
        val maxima: IntArray,
        val minima: IntArray,
        val zeroCrossings: Int,
    ) {
        val totalCount: Int get() = maxima.size + minima.size
    }

    private companion object {
        const val MIN_SIGNAL_SIZE = 4
        const val MIN_EXTREMA_FOR_SIFTING = 2
        const val MIN_IMF_ENERGY = 1e-10
        const val DIVISION_EPSILON = 1e-12
    }
}

/** Not-a-knot cubic spline, matching scipy.interpolate.CubicSpline defaults. */
internal object RppgCubicSpline {
    fun interpolate(x: DoubleArray, y: DoubleArray, outputSize: Int): DoubleArray? {
        if (x.size != y.size || x.size < 2 || x.any { !it.isFinite() } || y.any { !it.isFinite() }) {
            return null
        }
        if ((1 until x.size).any { index -> x[index] <= x[index - 1] }) return null
        if (x.size == 2) {
            return DoubleArray(outputSize) { sample ->
                y[0] + (y[1] - y[0]) * ((sample - x[0]) / (x[1] - x[0]))
            }
        }
        val second = secondDerivativesNotAKnot(x, y) ?: return null
        val output = DoubleArray(outputSize)
        var interval = 0
        for (sample in 0 until outputSize) {
            val point = sample.toDouble()
            while (interval < x.lastIndex - 1 && point > x[interval + 1]) interval += 1
            val h = x[interval + 1] - x[interval]
            val a = (x[interval + 1] - point) / h
            val b = (point - x[interval]) / h
            output[sample] = a * y[interval] + b * y[interval + 1] +
                ((a * a * a - a) * second[interval] +
                    (b * b * b - b) * second[interval + 1]) * h * h / 6.0
        }
        return output.takeIf { values -> values.all(Double::isFinite) }
    }

    private fun secondDerivativesNotAKnot(x: DoubleArray, y: DoubleArray): DoubleArray? {
        if (x.size == 3) {
            val leftSlope = (y[1] - y[0]) / (x[1] - x[0])
            val rightSlope = (y[2] - y[1]) / (x[2] - x[1])
            val second = 2.0 * (rightSlope - leftSlope) / (x[2] - x[0])
            return DoubleArray(3) { second }
        }
        val n = x.size
        val h = DoubleArray(n - 1) { x[it + 1] - x[it] }
        val unknowns = n - 2
        val lower = DoubleArray(unknowns)
        val diagonal = DoubleArray(unknowns)
        val upper = DoubleArray(unknowns)
        val rhs = DoubleArray(unknowns)
        for (row in 0 until unknowns) {
            val i = row + 1
            val previousH = h[i - 1]
            val nextH = h[i]
            rhs[row] = 6.0 * (
                (y[i + 1] - y[i]) / nextH - (y[i] - y[i - 1]) / previousH
                )
            when (row) {
                0 -> {
                    diagonal[row] = (previousH + nextH) * (2.0 + previousH / nextH)
                    upper[row] = nextH - previousH * previousH / nextH
                }
                unknowns - 1 -> {
                    lower[row] = previousH - nextH * nextH / previousH
                    diagonal[row] = (previousH + nextH) * (2.0 + nextH / previousH)
                }
                else -> {
                    lower[row] = previousH
                    diagonal[row] = 2.0 * (previousH + nextH)
                    upper[row] = nextH
                }
            }
        }
        val interior = solveTridiagonal(lower, diagonal, upper, rhs) ?: return null
        val result = DoubleArray(n)
        interior.copyInto(result, destinationOffset = 1)
        result[0] = ((h[0] + h[1]) * result[1] - h[0] * result[2]) / h[1]
        result[n - 1] = (
            (h[n - 3] + h[n - 2]) * result[n - 2] - h[n - 2] * result[n - 3]
            ) / h[n - 3]
        return result.takeIf { values -> values.all(Double::isFinite) }
    }

    private fun solveTridiagonal(
        lower: DoubleArray,
        diagonal: DoubleArray,
        upper: DoubleArray,
        rhs: DoubleArray,
    ): DoubleArray? {
        val n = diagonal.size
        val c = upper.copyOf()
        val d = rhs.copyOf()
        val b = diagonal.copyOf()
        for (index in 1 until n) {
            if (abs(b[index - 1]) < PIVOT_EPSILON) return null
            val factor = lower[index] / b[index - 1]
            b[index] -= factor * c[index - 1]
            d[index] -= factor * d[index - 1]
        }
        if (abs(b.last()) < PIVOT_EPSILON) return null
        val solution = DoubleArray(n)
        solution[n - 1] = d[n - 1] / b[n - 1]
        for (index in n - 2 downTo 0) {
            if (abs(b[index]) < PIVOT_EPSILON) return null
            solution[index] = (d[index] - c[index] * solution[index + 1]) / b[index]
        }
        return solution
    }

    private const val PIVOT_EPSILON = 1e-12
}
