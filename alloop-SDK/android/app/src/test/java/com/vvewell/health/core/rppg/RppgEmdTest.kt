package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgEmdTest {
    @Test
    fun defaultsAreExplicitlyFrozenToEmdSignalOnePointNine() {
        val config = RppgEmdConfig()

        assertEquals(2, config.mirroredExtremaCount)
        assertEquals(0.2, config.standardDeviationThreshold, 0.0)
        assertEquals(0.001, config.scaledVarianceThreshold, 0.0)
        assertEquals(0.2, config.energyRatioThreshold, 0.0)
        assertEquals(0.001, config.residueRangeThreshold, 0.0)
        assertEquals(0.005, config.residueAbsoluteSumThreshold, 0.0)
        assertEquals(1_000, config.maximumSiftIterations)
    }

    @Test
    fun decompositionSeparatesImfsFromResidueAndReconstructsInput() {
        val sampleRate = 30.0
        val input = DoubleArray(600) { index ->
            val time = index / sampleRate
            sin(2.0 * PI * 1.2 * time) + 0.25 * sin(2.0 * PI * 0.25 * time) + 0.01 * time
        }

        val outcome = RppgEmd().decompose(input)

        assertTrue(outcome.toString(), outcome is RppgEmdOutcome.Success)
        val result = outcome as RppgEmdOutcome.Success
        assertTrue(result.converged)
        assertTrue(result.imfs.isNotEmpty())
        assertEquals(input.size, result.residue.size)
        assertNotEquals(result.imfs.last().toList(), result.residue.toList())
        input.indices.forEach { index ->
            val reconstructed = result.imfs.sumOf { it[index] } + result.residue[index]
            assertEquals(input[index], reconstructed, 1e-8)
        }
    }

    @Test
    fun nonConvergenceIsExplicitFailure() {
        val signal = DoubleArray(300) { index -> sin(2.0 * PI * 1.2 * index / 30.0) }
        val emd = RppgEmd(RppgEmdConfig(maximumSiftIterations = 0))

        val outcome = emd.decompose(signal)

        assertTrue(outcome is RppgEmdOutcome.Failure)
        assertTrue(!outcome.converged)
        assertEquals(
            RppgEmdFailure.DidNotConverge,
            (outcome as RppgEmdOutcome.Failure).reason,
        )
    }

    @Test
    fun nonFiniteInputFailsWithoutThrowing() {
        val outcome = RppgEmd().decompose(doubleArrayOf(0.0, 1.0, Double.NaN, -1.0))

        assertTrue(outcome is RppgEmdOutcome.Failure)
        assertEquals(
            RppgEmdFailure.NonFiniteInput,
            (outcome as RppgEmdOutcome.Failure).reason,
        )
    }
}
